#!/usr/bin/perl

use strict;

package ACMBot::test;

use ACMBot::core;

my $core = ACMBot::core -> new( config => 'acmbot.conf' );
my $test = $core -> mdb();

unless( $test )
{
	die 'fail :(';
}

$test = $test -> select( 'select count(*) as id from mantis_bug_table;' );

print $test -> { id } . "\n";

exit 0;
