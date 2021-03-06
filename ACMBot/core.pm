#!/usr/bin/perl

package ACMBot::core;

use strict;

use ACMBot::core::Config;
use ACMBot::core::Db;
use ACMBot::core::XMPP;

use ACMBot::mantis;

our $Actual = undef;

sub new
{
	if( defined $ACMBot::core::Actual )
	{
		return $ACMBot::core::Actual;
	}

	my $proto = shift;
	my $class = ( ref( $proto ) or $proto );

	my %args = @_;

	my $self = { config => undef,
		     db     => undef,
		     mdb    => undef,
		     bot    => undef,
		     mantis => undef,
		     uptime => undef,
		     auth_callback => undef,
		     ARGV   => \%args };

	bless( $self, $class );

	$self -> { uptime } = time();

	unless( $self -> config( $args{ config } ) and
		$self -> dbup() and
		$self -> bot() and
		$self -> mantis() )
	{
		$self = undef;
	}

	if( defined $self )
	{
		$ACMBot::core::Actual = $self;
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

sub uptime
{
	my $self = shift;
	return ( time() - $self -> { uptime } );
}

sub bot
{
	my $self = shift;

	unless( defined $self -> { bot } )
	{
		my $config = $self -> config -> full();
		$self -> { bot } = ACMBot::core::XMPP -> new( ( %$config, ( callbacks => ( $self -> { ARGV } -> { 'callbacks' } || undef ) ) ) );
	}

	return $self -> { bot };
}

sub mantis
{
	my $self = shift;

	unless( defined $self -> { mantis } )
	{
		$self -> { mantis } = ACMBot::mantis -> new( version => $self -> config -> get( 'mver' ),
							     dbh     => $self -> mdb() );
	}

	return $self -> { mantis };
}

sub dbup
{
	my $self = shift;
	my $result = 0;

	if( $self -> config -> get( 'usesamedb' ) eq '1' )
	{
		$result = ( ( $self -> db() or $self -> mdb() ) or
			    ( $self -> mdb() or $self -> db() ) );
	} else
	{
		$result = ( $self -> db() and $self -> mdb() );
	}

	return $result;
}

sub db
{
	my $self = shift;

	if( ( $self -> config -> get( 'usesamedb' ) eq '1' ) and defined $self -> { mdb } )
	{
		$self -> { db } = $self -> { mdb };
	}

	unless( defined $self -> { db } )
	{
		$self -> { db } = ACMBot::core::Db -> new( map{ $_ => $self -> config -> get( $_ ) } ( 'dbname', 'dbhost', 'dbuser', 'dbpass', 'dbport', 'dbdriver' ) );
	}

	return $self -> { db };
}

sub mdb
{
	my $self = shift;

	if( ( $self -> config -> get( 'usesamedb' ) eq '1' ) and defined $self -> { db } )
	{
		$self -> { mdb } = $self -> { db };
	}

	unless( defined $self -> { mdb } )
	{
		my $prep = sub
		{
			my $val = shift;
			$val =~ s/^m//;
			return $val;
		};

		$self -> { mdb } = ACMBot::core::Db -> new( map{ $prep -> ( $_ ) => $self -> config -> get( $_ ) } ( 'mdbname', 'mdbhost', 'mdbuser', 'mdbpass', 'mdbport', 'mdbdriver' ) );
	}

	return $self -> { mdb };
}

sub set_auth_callback
{
	my $self = shift;
	$self -> { auth_callback } = shift;
	return defined $self -> { auth_callback };
}

sub set_callbacks
{
	my $self = shift;
	return $self -> bot -> set_callbacks( @_ );
}

1;
