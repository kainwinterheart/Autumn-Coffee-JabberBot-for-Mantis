#!/usr/bin/perl

package ACMBot::core;

use strict;

use ACMBot::core::Config;
use ACMBot::core::Db;

sub new
{
	my $proto = shift;
	my $class = ( ref( $proto ) or $proto );

	my %args = @_;

	my $self = { config => undef,
		     db     => undef,
		     mdb    => undef,
		     ARGV   => \%args };

	bless( $self, $class );
	return $self;
}

sub config
{
	my ( $self, $cfile ) = @_;

	unless( defined $self ->  { config } )
	{
		$self ->  { config } = ACMBot::core::Config -> new();

		unless( $self ->  { config } -> load( ( $cfile or $self -> { ARGV } -> { config } ) ) )
		{
			die $!;
		}
	}

	return $self ->  { config };
}

sub db
{
	my $self = shift;
	return 1;
}

sub mdb
{
	my $self = shift;
	return 1;
}

1;