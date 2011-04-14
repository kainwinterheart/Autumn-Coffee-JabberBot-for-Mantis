#!/usr/bin/perl

use strict;

package ACMBot::test;

use ACMBot::core;

print "Connecting...\n";

my $core = ACMBot::core -> new( config => 'acmbot.conf' );

unless( $core )
{
	die 'fail :(';
}

$core -> bot -> client -> Connected() ? print "Connected.\n" : die 'Can\'t connect.';
print $core -> bot -> client -> GetErrorCode() . "\n";

while( 1 )
{
#	unless( defined $core -> bot -> client -> Process( 5 ) )
#	{
#		last;
#	}
	sleep( 1 );
}

# $test = $test -> select( 'select count(*) as id from mantis_bug_table;' );

# print $test -> { id } . "\n";

exit 0;
