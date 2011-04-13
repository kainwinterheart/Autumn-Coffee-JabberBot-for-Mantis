#!/usr/bin/perl

use strict;

package ACMBot::test;

use ACMBot::core::Config;

my $config = ACMBot::core::Config -> new();

unless( $config -> load( '/home/kain/git-projects/perl/acmantisbot/acmbot.conf' ) )
{
	die $!;
}

foreach my $key ( $config -> keys() )
{
	print $key . ' => ' . $config -> get( $key ) . "\n";
}

exit 0;
