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

	unless( $self -> config( $args{ config } ) )
	{
		die $!;
	}

	return $self;
}

sub config
{
	my ( $self, $cfile ) = @_;

	unless( defined $self ->  { config } )
	{
		$self -> { config } = ACMBot::core::Config -> new();

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

	unless( defined $self -> { db } )
	{
		$self -> { db } = ACMBot::core::Db -> new( map{ $_ => $self -> config -> get( $_ ) } ( 'dbname', 'dbhost', 'dbuser', 'dbpass', 'dbport', 'dbdriver' ) );
	}

	return $self -> { db };
}

sub mdb
{
	my $self = shift;

	my $prep = sub
	{
		my $val = shift;
		$val =~ s/^m//;
		return $val;
	};

	unless( defined $self -> { mdb } )
	{
		$self -> { mdb } = ACMBot::core::Db -> new( map{ $prep -> ( $_ ) => $self -> config -> get( $_ ) } ( 'mdbname', 'mdbhost', 'mdbuser', 'mdbpass', 'mdbport', 'mdbdriver' ) );
	}

	return $self -> { mdb };
}

1;