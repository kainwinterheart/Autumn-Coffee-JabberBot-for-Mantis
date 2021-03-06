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
		     ARGV => \%args,
		     trim => sub
		     {
		             my $val = shift;
		             $val =~ s/^\s+|\s+$//g;
		             return $val;
		     } };

	bless( $self, $class );

	unless( $self -> connect() )
	{
		$self = undef;
	}

	return $self;
}

sub connect
{
	my $self = shift;

	unless( defined $self -> { dbh } )
	{
		my $db_str = 'database';
		if( uc( $self -> { ARGV } -> { dbdriver } ) eq 'PG' )
		{
			$db_str = 'dbname';
		}

		$self -> { dbh } = ( DBI -> connect( sprintf( 'DBI:%s:%s=%s;host=%s;port=%s',
							      $self -> { ARGV } -> { dbdriver },
							      $db_str,
							      $self -> { ARGV } -> { dbname },
							      $self -> { ARGV } -> { dbhost },
							      $self -> { ARGV } -> { dbport } ),
						     $self -> { ARGV } -> { dbuser },
						     $self -> { ARGV } -> { dbpass } ) || undef );
	}

	return $self -> { dbh };
}

sub disconnect
{
	my $self = shift;

	if( defined $self -> { dbh } )
	{
		if( $self -> { dbh } -> disconnect() )
		{
			$self -> { dbh } = undef;
		}
	}

	return not defined $self -> { dbh };
}

sub reconnect
{
	my $self = shift;

	if( $self -> disconnect() )
	{
		sleep 1;
		$self -> connect();
	}

	return defined $self -> { dbh };
}

sub dbh
{
	my $self = shift;
	return $self -> connect( @_ );
}

sub do
{
	my $self = shift;
	return $self -> dbh -> do( shift );
}

sub quote
{
	my $self = shift;
	return $self -> dbh -> quote( shift );
}

sub select
{
	my $self = shift;
	my $sth = $self -> dbh -> prepare( shift );

	{
		my $result = $sth -> execute();
		unless( $result )
		{
			return 0;
		}
	}

	my $row = $sth -> fetchrow_hashref();
	$sth -> finish();

	return $row;
}

sub multi_select
{
	my $self = shift;
	my $sth = $self -> dbh -> prepare( shift );

	{
		unless( $sth -> execute() )
		{
			return undef;
		}
	}

	my %output = {};

	while( my $row = $sth -> fetchrow_hashref() )
	{
		$output{ $self -> { trim } -> ( $row -> { 'id' } ) } = $self -> { trim } -> ( $row );
	}

	$sth -> finish();

	return \%output;
}

1;
