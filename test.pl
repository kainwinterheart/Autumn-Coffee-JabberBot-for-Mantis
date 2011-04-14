#!/usr/bin/perl

use strict;

package ACMBot::test;

use ACMBot::core;

my $core = ACMBot::core -> new( config => '/home/kain/git-projects/perl/acmantisbot/acmbot.conf' );
$core -> db();
$core -> mdb();
#my $test = $core -> mdb();

# my $conf = $core -> config();

#foreach my $key ( $conf -> keys() )
#{
#	print $key . ' => ' . $conf -> get( $key ) . "\n";
#}

#print $test -> connect();

#unless( $test )
#{
#	die 'fail :(';
#}

# $test = $test -> select( 'select count(*) as id from mantis_bug_table;' );

#print $test -> { id } . "\n";

exit 0;
