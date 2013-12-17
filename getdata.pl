#!/usr/bin/perl -w

use strict;
use LWP::UserAgent;
use JSON::Parse qw/json_to_perl /;
use Data::Dumper;
use Encode;
use utf8;
use DateTime;

my $browser = LWP::UserAgent->new;

my $startdate = '20050101';
my $year = substr $startdate, 0, 4;
my $month = substr $startdate, 4, 2;
my $day = substr $startdate, 6, 2;
#print "+++ yyyymmdd = $year, $month, $day\n";
my $dt_start = DateTime->new (
	year => $year, 
	month => $month,
	day => $day
);
my $dt_current = $dt_start->clone();
my $current = '';

print "date\t\tmaxh\tmaxt\tmaxw\tminh\tmint\tprecipm\n";

for my $i (1..10)
{
	$year = $dt_current->year;
	$month = $dt_current->month;	
	$day = $dt_current->day;
	$current = sprintf("%.4d%.2d%.2d", $year, $month, $day);
#	print "+++ $i\tcurrent = $current\n";

	my $link = "http://api.wunderground.com/api/fbc04d9a408e82ca/history_$current/q/MA/Boston.json";
#	print "$link\n";
	my $response = $browser->get($link);
	#my $flag = Encode::is_utf8($response->content, 1);
	#print "IS UTF8 $flag\n";
	my $string = '';
	$string = encode('utf8', $response->content);
	#$flag = Encode::is_utf8($string, 1);
	#print "IS UTF8 $flag\n";
	#print Dumper $string;

	my $perl = '';
	$perl = json_to_perl($string);
	#print ref $perl, "\n";
#	print Dumper $perl;
	#print Dumper $perl->{'history'}->{'dailysummary'}, "\n";

	print "$current\t";
	foreach my $k (sort keys $perl->{'history'}->{'dailysummary'}->[0])
	{
		next unless $k =~ m/mintempm|maxtempm|maxwspdm|minhumidity|maxhumidity|precipm/i;
		print $perl->{'history'}->{'dailysummary'}->[0]->{$k}, "\t";
	}
	print "\n";

	$dt_current->add( days => 1); 
	sleep(7);
}






















