#!/usr/bin/perl -w

use strict;
use LWP::UserAgent;
use JSON::Parse qw/json_to_perl /;
use Data::Dumper;
use Encode;
use utf8;
use DBI;
use DBD::mysql;
use DateTime::Format::MySQL;
use DateTime::TimeZone;

my $host_bizviz = 'xxx.boston.com';
my $db_bizviz = 'xxx';
my $user_bizviz = 'xxx';
my $pw_bizviz = 'xxx';
my $t_weather = 'weather';

my $dsn_bizviz = "dbi:mysql:$db_bizviz:$host_bizviz;mysql_connect_timeout=36000;mysql_enable_utf8=1";
my $connect_bizviz = DBI->connect($dsn_bizviz, $user_bizviz, $pw_bizviz) or die "\tWARNING (", scalar localtime(), ")\n\t", "can't connect the BIZVIZ database...\n";
$connect_bizviz->{'AutoCommit'} = 1;
$connect_bizviz->{'mysql_auto_reconnect'} = 1;
my ($query_bizviz, $query_handle_bizviz);

open HOURLY, "< hourly2db.txt" or die "can't open hourly2db.txt: $!\n";

my @colnames = ();

while (my $line = <HOURLY>)
{
	chomp $line;
	unless ($line =~ m/^\d/)
	{
		@colnames = split /\t/, $line;
		print "the first line \n";
		print @colnames, "\n";
		next;
	}
	
	my @items = split /\t/, $line;
	print "items have ", $#items, "\n";
	print "colnames have ", $#colnames, "\n";

	my $year = substr $items[0], 0, 4;
	my $month = substr $items[0], 4, 2;
	my $day = substr $items[0], 6, 2;
	my $hour = $items[2];
	my $min = $items[3];
	my $dt = DateTime->new (
		year => $year, 
		month => $month,
		day => $day,
		hour => $hour,
		minute => $min
	);
	my $dt_sql = DateTime::Format::MySQL->format_datetime($dt); 
	$query_bizviz = "insert into $t_weather (time, conds) value ('$dt_sql', '$items[1]')";
	print "QUERY:\t$query_bizviz\n";
	$query_handle_bizviz = $connect_bizviz->prepare($query_bizviz);
	$query_handle_bizviz->execute();

	$query_bizviz = "select max(id) from $t_weather ";
	print "QUERY:\t$query_bizviz\n";
	$query_handle_bizviz = $connect_bizviz->prepare($query_bizviz);
	$query_handle_bizviz->execute();

	my @row = $query_handle_bizviz->fetchrow_array();
	my $id = $row[0];
	print "======== id = $id ============ \n";
	for my $i (4..$#colnames)
	{
		print $i, "\t", $colnames[$i], ": ", $items[$i], "\n";
		if ($items[$i] eq '-999' or $items[$i] eq '-9999')
		{
			print ">>> $colnames[$i] is null\n";
			next;
		}
		
# 		if ($colnames[$i] eq 'windchills' and $items[$i] > $items[20])
# 		{
# 			print ">>> windchill is larger than temperature\n";
# #			$items[$i] = -9999;
# 			next;
# 		}

		$items[$i] =~ s/'/\\'/g;
		$items[$i] =~ s/"/\\"/g;
		$query_bizviz = "update $t_weather set $colnames[$i]='$items[$i]' where id='$id' ";
		print "QUERY:\t$query_bizviz\n";
		$query_handle_bizviz = $connect_bizviz->prepare($query_bizviz);
		$query_handle_bizviz->execute();
		
	}
	
	my $wc = &windchill($items[19], $items[31]);
	my $hi = &heatindex($items[19], $items[10]);
	
	$query_bizviz = "update $t_weather set windchilli_s='$wc', heatindexi_s='$hi' where id='$id' ";
	print "QUERY:\t$query_bizviz\n";
	$query_handle_bizviz = $connect_bizviz->prepare($query_bizviz);
	$query_handle_bizviz->execute();
	
	
	print '-'x70, "\n";
#	last;
}

close HOURLY;

sub heatindex 
{
	my ($t, $h) = @_;
	$h /= 100;
	my @c = (0, -42.379, 2.04901523, 10.14333127, -0.22475541, -6.83783E-3, -5.481717E-2, 1.22874E-3, 8.5282E-4, -1.99E-6);
#	my @c = (0, 0.363445176, 0.988622465, 4.777114035, -0.114037667, -0.000850208, -0.020716198, 0.000687678, 0.000274954, 0);
	my $hi = $c[1]+$c[2]*$t+$c[3]*$h+$c[4]*$t*$h+$c[5]*$t**2+$c[6]*$h**2+$c[7]*$t**2*$h+$c[8]*$t*$h**2+$c[9]*$t**2*$h**2;
	$hi = $hi > $t ? $hi : -9999;
	return $hi;
}

sub windchill
{
	my ($t, $w) = @_;
	my $wc = 35.74+0.6215*$t-35.75*$w**0.16+0.4275*$t*$w**0.16;
	$wc = $wc < $t ? $wc : -9999;
	return $wc;
}
