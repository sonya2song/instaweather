#!/usr/bin/perl -w

use strict;
use DateTime;
use DateTime::Format::MySQL;
use Data::Dumper;
use JSON::Parse qw/json_to_perl /;
use DBI;
use DBD::mysql;

my $host_snap = 'xxx.boston.com';
my $db_snap = 'xxx';
my $user_snap = 'xxx';
my $pw_snap = 'xxx';
my $dsn_snap = "dbi:mysql:$db_snap:$host_snap;mysql_connect_timeout=36000;mysql_enable_utf8=1";
my $connect_snap = DBI->connect($dsn_snap, $user_snap, $pw_snap) or die "\tWARNING (", scalar localtime(), ")\n\t", "can't connect the SNAP database...\n";
$connect_snap->{'AutoCommit'} = 1;
$connect_snap->{'mysql_auto_reconnect'} = 1;
my ($query_snap, $query_handle_snap);

my $host_bizviz = 'xxx.boston.com';
my $db_bizviz = 'xxx';
my $user_bizviz = 'xxx';
my $pw_bizviz = 'xxx';
my $dsn_bizviz = "dbi:mysql:$db_bizviz:$host_bizviz;mysql_connect_timeout=36000;mysql_enable_utf8=1";
my $connect_bizviz = DBI->connect($dsn_bizviz, $user_bizviz, $pw_bizviz) or die "\tWARNING (", scalar localtime(), ")\n\t", "can't connect the BIZVIZ database...\n";
$connect_bizviz->{'AutoCommit'} = 1;
$connect_bizviz->{'mysql_auto_reconnect'} = 1;
my ($query_bizviz, $query_handle_bizviz);

my $t_elements = 'elements';
my $t_weather = 'weather';

$query_snap = "select id, json from $t_elements limit 1  "; #where created_time is null
print "QUERY:\t$query_snap\n";
$query_handle_snap = $connect_snap->prepare($query_snap);
$query_handle_snap->execute();

my $dt_invalid = DateTime->from_epoch(epoch => 0);
$dt_invalid = DateTime::Format::MySQL->format_datetime($dt_invalid); 

my $total = 1198819;
my $i = 0;

while (my @row = $query_handle_snap->fetchrow_array())
{
	print $i++, "/", $total, "\n";
	my $perl = json_to_perl ($row[1]);
	print Dumper $perl;
}	

























