#!/usr/bin/perl

package ACMBot::core::Db;

use strict;

use DBI;

sub new
{
	my $proto = shift;
	my $class = ( ref( $proto ) or $proto );

	my %args = @_;

	foreach my $key ( keys %args )
	{
		print $key . ' => ' . $args{ $key } . "\n";
	}

	my $self = { dbh  => undef,
		     ARGV => \%args,
		     trim => sub
		     {
		             my $val = shift;
		             $val =~ s/^\s+|\s+$//g;
		             return $val;
		     } };

	bless( $self, $class );
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

sub dbh
{
	my $self = shift;
	return $self -> connect( @_ );
}

sub do
{
	my $self = shift;
	my $dbh = $self -> dbh();
	return $dbh -> do( shift );
}

sub quote
{
	my $self = shift;
	my $dbh = $self -> dbh();
	return $dbh -> quote( shift );
}

sub select
{
	my $self = shift;

	my $dbh = $self -> dbh();
	my $sth = $dbh -> prepare( shift );

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

	my $dbh = $self -> dbh();
	my $sth = $dbh -> prepare( shift );

	{
		my $result = $sth -> execute();
		unless( $result )
		{
			return 0;
		}
	}

	my %output = {};

	while( my $row = $sth -> fetchrow_hashref() )
	{
		$output{ $self -> { trim }( $row -> { 'id' } ) } = $self -> { trim }( $row );
	}

	$sth -> finish();

	return \%output;
}

1;
