#!/usr/bin/perl -w

use strict;
use LWP::UserAgent;
use LWP::Simple;
use JSON::Parse qw/json_to_perl valid_json/;
use Data::Dumper;
use Encode;
use utf8;
use DateTime;
use DBI;
use DBD::mysql;
use DateTime::Format::MySQL;
use String::Similarity;

my $host_snap = 'xxx.boston.com';
my $db_snap = 'xxx';
my $user_snap = 'xxx';
my $pw_snap = 'xxx';
my $dsn_snap = "dbi:mysql:$db_snap:$host_snap;mysql_connect_timeout=36000;mysql_enable_utf8=1";
my $connect_snap = DBI->connect($dsn_snap, $user_snap, $pw_snap) or die "\tWARNING (", scalar localtime(), ")\n\t", "can't connect the SNAP database...\n";
$connect_snap->{'AutoCommit'} = 1;
$connect_snap->{'mysql_auto_reconnect'} = 1;
my ($query_snap, $query_handle_snap);

my $dsn_s = "dbi:mysql:$db_snap:$host_snap;mysql_connect_timeout=36000;mysql_enable_utf8=1";
my $connect_s = DBI->connect($dsn_snap, $user_snap, $pw_snap) or die "\tWARNING (", scalar localtime(), ")\n\t", "can't connect the SNAP database...\n";
$connect_s->{'AutoCommit'} = 1;
$connect_s->{'mysql_auto_reconnect'} = 1;
my ($query_s, $query_handle_s);

my $t_elements = 'elements';
my $t_weather = 'weather';
my $t_fc_img = 'forecast_img';
my $t_fc10day = 'forecast10day';

my $tempthreshold = 4; #temperature difference that's acceptable
my $condsthreshold = 1; #conditions

my $browser = LWP::UserAgent->new;

#goto REMOVE;

my $link = "http://api.wunderground.com/api/fbc04d9a408e82ca/forecast10day/q/MA/Boston.json";
my $response = $browser->get($link);
my $string = '';
$string = encode('utf8', $response->content);

my $perl = '';
if (valid_json $string)
{
	$perl = json_to_perl($string);
}
else
{
	print DateTime->now(), ": weather forecast has invalid json. exiting now\n";
	exit 0;
}
my @urls = ();

$query_snap = "delete from $t_fc10day";
print "QUERY:\t$query_snap\n";
$query_handle_snap = $connect_snap->prepare($query_snap);
$query_handle_snap->execute();

$query_snap = "delete from $t_fc_img  "; 
print "QUERY:\t$query_snap\n";
$query_handle_snap = $connect_snap->prepare($query_snap);
$query_handle_snap->execute();

foreach my $array (@{$perl->{'forecast'}->{'simpleforecast'}->{'forecastday'}})
{
#	print ref $array, "\n";
	my $datechosen = '';
	my @diff24;
	my @diffallmin;
	my $diffmin = 1000; #lowest temp diff
	
 	my $period = $array->{'period'};
 	
 	if ($period == 1)
 	{
		next;
#  		$datechosen = "date(created_at)='".DateTime->now()->ymd()."'";
#  		goto SEEKIMG; #if today, use today's images
 	}

	my $conditions = $array->{'conditions'};
	my $icon_url = $array->{'icon_url'};
	my $high = $array->{'high'}->{'fahrenheit'};
	my $low = $array->{'low'}->{'fahrenheit'};
	my $avew = $array->{'avewind'}->{'mph'};
	my $avewdir = $array->{'avewind'}->{'dir'};
	my $aveh = $array->{'avehumidity'};
	my $maxh = $array->{'maxhumidity'};
	my $minh = $array->{'minhumidity'};
	my $hi = &heatindex($high, $maxh);
	my $wc = &windchill($high, $avew);
	$wc = $high if $wc > $high;
	$hi = $high if $hi < $high; 
	
	my $dt_reported = DateTime->now();
	$dt_reported = DateTime::Format::MySQL->format_datetime($dt_reported);
	my $dt_current = DateTime->today();
	$dt_current->add(days=>$period-1);
	print $dt_current->ymd(), ", $conditions, $wc\n"; #\thigh: $high\tlow: $low\tfeels like: $wc\twind: $avew\thumidity: $aveh\n";
	$dt_current = DateTime::Format::MySQL->format_datetime($dt_current);

	$query_snap = "insert into $t_fc10day (reported_at, period, futuredate, conditions, icon_url, high, low, windspd, winddir, maxh, minh) values ('$dt_reported', '$period', '$dt_current', '$conditions', '$icon_url', '$high', '$low', '$avew', '$avewdir', '$maxh', '$minh') ";
#	print "QUERY:\t$query_snap\n";
	$query_handle_snap = $connect_snap->prepare($query_snap);
	$query_handle_snap->execute();

	$conditions = 'rain' if $conditions =~ m/rain/i;
	$conditions = 'snow' if $conditions =~ m/snow/i;
	$conditions = 'cloudy' if $conditions =~ m/cloud/i;
	
	if ($conditions =~ m/\s/)
	{
		my @items = split /\s/, $conditions;
		$conditions = pop @items;
	}
	
	
#	my $dt_start = DateTime->now();
#	$dt_start->subtract(years=>1, days=>7);
#	$dt_start->subtract(days=>31-$period);
#	$dt_start->add(days=>$period);
#	$dt_start = DateTime::Format::MySQL->format_datetime($dt_start);
#	my $dt_end = DateTime->now();
#	$dt_end->subtract(years=>1);
#	$dt_end->add(days=>7+$period);
#	$dt_end = DateTime::Format::MySQL->format_datetime($dt_end);

	$query_snap = "select date(time), conds, tempm, hum, wspdi, windchilli_s from $t_weather where date(time) between '2012-5-17' and '2013-3-19' and hour(time) between 12 and 16 "; # 2012-5-17
#	print "QUERY:\t$query_snap\n";
	$query_handle_snap = $connect_snap->prepare($query_snap);
	$query_handle_snap->execute();
	
#	1. only temp diff within 1 degree is chosen, stored in @diff24
#	2. sort out the highest similar conds within @diff24
#	3. if no temp is within 1 degree diff, choose the lowest possible, stored in @diffallmin
#	4. sort out the highest similar conds from @diffallmin

	while (my @row = $query_handle_snap->fetchrow_array())
	{
		my $date = $row[0];
		my $conds = $row[1];

		if ($conds =~ m/\s/)
		{
			my @items = split /\s/, $conds;
			$conds = pop @items;
		}

		my $feels = $row[5] == -9999 ? $row[2] : $row[5];
		my $sim = similarity(lc($conditions), lc($conds)); # +rand(1)/100_000
#		$sim = 1 if $sim > 1;
		my $diff = ($wc - $feels)**2;
#		print "$date, $conds, $feels, $sim, $diff\n";
		
		if ($diffmin > $diff)
		{
			$diffmin = $diff;
			@diffallmin = join('#', $date, $sim, $diff);
		}

		if ($diff < $tempthreshold and $sim >= $condsthreshold)
		{
#			push @diff24, join('#', $date, $sim, $diff);
#			push @diff24, $date;
			print "$date, $feels, $conds\n";
			push @diff24, $date, $sim;
			
		}
	}
	print '-'x70, "\n";
	
	if (scalar @diff24 == 0)
	{
		my $dt_yesterday = DateTime->now();
		$dt_yesterday->subtract(days=>1);
		$datechosen = "date(created_at)='".$dt_yesterday->ymd()."'";
	}
	else
	{
		my %pairs = @diff24;
		my %dates = ();
		$datechosen = '(';

		foreach my $k (keys %pairs)
		{
			$datechosen .= "date(created_at)='$k' or "; # if not undef $dates{$pairs{$k}};
#			$dates{$pairs{$k}} = 1;
		}
		$datechosen = substr $datechosen, 0, -4;
		$datechosen .= ") ";
	#	$datechosen = DateTime::Format::MySQL->parse_date($datechosen);
	#	$datechosen = DateTime::Format::MySQL->format_datetime($datechosen);
	}
	
	$query_snap = "select id, json, caption_text, created_at from $t_elements where (listed_location_name like '%boston common%') and $datechosen and caption_text not like '%lingerie%' and caption_text not like '%underwear%' and caption_text not like '%panties%' order by rand() limit 100 "; #   and hour(created_at) between 8 and 18  or (lat between '42.3529' and '42.3569' and lng between '-71.0696' and '-71.0628')
#	$query_snap = "select id, json, caption_text, created_at from $t_elements where ((caption_text like '%#ootd%' or caption_text like '%#styleblogger%' or caption_text like '%#fashionblogger%') and caption_text not like '%lingerie%') and $datechosen "; # or caption_text like '%selfportrait%'
	print "QUERY:\t$query_snap\n";
	$query_handle_snap = $connect_snap->prepare($query_snap);
	$query_handle_snap->execute();

SEEKIMG:
	
	my $count = 0;
	while (my @row = $query_handle_snap->fetchrow_array())
	{
		$count++;
		my $caption = $row[2];
		my $created_at = $row[3];
		my $json = $row[1];
		$json =~ s/[^[:print:]]+//g;
		$json = encode 'utf8', $json;
#		print "$json\n";
		my $inst = '';
		my %used_links;
		
		if (valid_json $json)
		{
			$inst = json_to_perl($json);
			my $user = $inst->{'user'}->{'username'};
			my $inst_link = $inst->{'link'};
			my $img_low = $inst->{'images'}->{'low_resolution'}->{'url'};
			my $img_std = $inst->{'images'}->{'standard_resolution'}->{'url'};
			my $img_tbn = $inst->{'images'}->{'thumbnail'}->{'url'};
			my $popularity = $inst->{'comments'}->{'count'} + $inst->{'likes'}->{'count'};
			$popularity = 0 unless defined $popularity;
			next unless $user and $created_at and $inst_link and $img_low and $img_std and $img_tbn;

			if (not defined $used_links{$inst_link})
			{
#				print "$user and $created_at and $inst_link and $img_low and $img_std and $img_tbn\n";
				$query_s = "insert ignore into $t_fc_img (period, created_at, user, link, img_low, img_std, img_tbn, popularity) value ('$period', '$created_at', '$user', '$inst_link', '$img_low', '$img_std', '$img_tbn', '$popularity') "; 
#				print "QUERY:\t$query_snap\n";
				$query_handle_s = $connect_s->prepare($query_s);
	 			$query_handle_s->execute();
				$used_links{$inst_link} = 1;
			}
			last if $count > 40;
			
		}
#		print Dumper $perl;
#		print '-'x70, "\n";
	}
#	print ">>>>>>>>>>>>>>>>>> count = $count <<<<<<<<<<<<<<<<<<<<<\n";
	if ($count == 0)
	{
		my $dt_lastweek = DateTime->now();
		$dt_lastweek->subtract(days=>7);
		$dt_lastweek = DateTime::Format::MySQL->format_datetime($dt_lastweek);

		$query_snap = "select id, json, caption_text, created_at from $t_elements where (listed_location_name like '%boston common%' or (lat between '42.3529' and '42.3569' and lng between '-71.0696' and '-71.0628')) and date(created_at)='$dt_lastweek' and caption_text not like '%lingerie%' and caption_text not like '%underwear%' and caption_text not like '%panties%' "; #   and hour(created_at) between 8 and 18 
	#	print "QUERY:\t$query_snap\n";
		$query_handle_snap = $connect_snap->prepare($query_snap);
		$query_handle_snap->execute();

		goto SEEKIMG;
	}
		
	
	print '='x70, "\n";
#	last;
}

# REMOVE BROKEN LINKS
REMOVE:

$query_snap = "select id, link, date(created_at) from $t_fc_img "; #
print "QUERY:\t$query_snap\n";
$query_handle_snap = $connect_snap->prepare($query_snap);
$query_handle_snap->execute();

while (my @row = $query_handle_snap->fetchrow_array())
{
	print "$row[0]\t$row[1]\n";
	my $resp = get("$row[1]");
	if (not defined length($resp))
	{
		print ">>> BROKEN on $row[2] <<<\n" ;
		$query_s = "delete from $t_fc_img where id='$row[0]' "; #
		print "QUERY:\t$query_s\n";
		$query_handle_s = $connect_snap->prepare($query_s);
		$query_handle_s->execute();
		
	}
}


sub heatindex 
{
	my ($t, $h) = @_;
	$h /= 100;
	my @c = (0, -42.379, 2.04901523, 10.14333127, -0.22475541, -6.83783E-3, -5.481717E-2, 1.22874E-3, 8.5282E-4, -1.99E-6);
#	my @c = (0, 0.363445176, 0.988622465, 4.777114035, -0.114037667, -0.000850208, -0.020716198, 0.000687678, 0.000274954, 0);
	return $c[1]+$c[2]*$t+$c[3]*$h+$c[4]*$t*$h+$c[5]*$t**2+$c[6]*$h**2+$c[7]*$t**2*$h+$c[8]*$t*$h**2+$c[9]*$t**2*$h**2;
}

sub windchill
{
	my ($t, $w) = @_;
	return 35.74+0.6215*$t-35.75*$w**0.16+0.4275*$t*$w**0.16;
}
