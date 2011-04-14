#!/usr/bin/perl

use strict;

package ACMBot::test;

use ACMBot::core;

my $core = ACMBot::core -> new( config => 'acmbot.conf' );
my $config = $core -> config();

foreach my $key ( $config -> keys() )
{
	print $key . ' => ' . $config -> get( $key ) . "\n";
}

unless( $core -> db() and $core -> mdb() )
{
	die $!;
}

exit 0;
