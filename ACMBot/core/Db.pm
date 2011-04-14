#!/usr/bin/perl

package ACMBot::core::Db;

use strict;

use DBI;

sub new
{
	my $proto = shift;
	my $class = ( ref( $proto ) or $proto );

	my %args = @_;

	my $self = { dbh  => undef,
		     ARGV => \%args };

	bless( $self, $class );
	return $self;
}

sub connect
{
	my $self = shift;

	my $db_str = 'database';
	if( uc( $self -> { ARGV } -> { dbdriver } ) eq 'PG' )
	{
		$db_str = 'dbname';
	}

	unless( defined $self -> { dbh } )
	{
		$self -> { dbh } = DBI -> connect( sprintf( 'DBI:%s:database=%s;host=%s;port=%s',
							    $db_str,
							    $self -> { ARGV } -> { dbname },
							    $self -> { ARGV } -> { dbhost },
							    $self -> { ARGV } -> { dbport } ),
						   $self -> { ARGV } -> { dbuser },
						   $self -> { ARGV } -> { dbpass } );
	}

	return $self -> { dbh };
}

1;
