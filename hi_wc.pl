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
my $t_weather = 'xxx';

my $dsn_bizviz = "dbi:mysql:$db_bizviz:$host_bizviz;mysql_connect_timeout=36000;mysql_enable_utf8=1";
my $connect_bizviz = DBI->connect($dsn_bizviz, $user_bizviz, $pw_bizviz) or die "\tWARNING (", scalar localtime(), ")\n\t", "can't connect the BIZVIZ database...\n";
$connect_bizviz->{'AutoCommit'} = 1;
$connect_bizviz->{'mysql_auto_reconnect'} = 1;
my ($query_bizviz, $query_handle_bizviz);

my $dsn_bv = "dbi:mysql:$db_bizviz:$host_bizviz;mysql_connect_timeout=36000;mysql_enable_utf8=1";
my $connect_bv = DBI->connect($dsn_bizviz, $user_bizviz, $pw_bizviz) or die "\tWARNING (", scalar localtime(), ")\n\t", "can't connect the BIZVIZ database...\n";
$connect_bv->{'AutoCommit'} = 1;
$connect_bv->{'mysql_auto_reconnect'} = 1;
my ($query_bv, $query_handle_bv);


$query_bizviz = "select id, tempi, wspdi, hum from $t_weather where windchilli_s is null or heatindexi_s is null ";  
print "QUERY:\t$query_bizviz\n";
$query_handle_bizviz = $connect_bizviz->prepare($query_bizviz);
$query_handle_bizviz->execute();
while (my @row = $query_handle_bizviz->fetchrow_array())
{
	print "@row\n";
	my $id = $row[0];
	my $t = $row[1];
	my $w = $row[2];
	my $h = $row[3];
	my $hi = &heatindex($t, $h);
	my $wc = &windchill($t, $w);
	print "hi = $hi, wc = $wc\n";

	$wc = -9999 if $wc > $t;
	$hi = -9999 if $hi < $t;
	$query_bv = "update $t_weather set windchilli_s='$wc', heatindexi_s='$hi' where id='$id' "; 
	print "QUERY:\t$query_bv\n";
	$query_handle_bv = $connect_bv->prepare($query_bv);
	$query_handle_bv->execute();

#	last;
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