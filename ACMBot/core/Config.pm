#!/usr/bin/perl

package ACMBot::core::Config;

use strict;

sub new
{
	my $proto = shift;

	my $class = ( ref( $proto ) or $proto );

	my $self = { config => undef,
		     trim => sub
		     {
		          my $val = shift;
		          $val =~ s/^\s+|\s+$//g;
		          return $val;
		     } };

	bless( $self, $class );

	return $self;
}

sub load
{
	my $self = shift;

	my @data = ();
	my %config = ();

	if( open( FILE, '<', shift ) )
	{
		@data = <FILE>;
		close( FILE );
	} else
	{
		return 0;
	}

	if( scalar @data )
	{
		foreach my $line ( @data )
		{
			my @pair = map{ $self -> { trim }( $_ ) } ( $line =~ m/^(.+?)=(.+?)$/g );
			if( ( scalar @pair ) == 2 )
			{
				%config = ( %config, @pair );
			}
		}
	} else
	{
		return 0;
	}

	$self -> { config } = \%config;
	return 1;
}

sub get
{
	my ( $self, $field ) = @_;
	return $self -> { config } -> { $field };
}

sub keys
{
	my $self = shift;
	my $proxy = $self -> { config };
	return ( keys %$proxy );
}

1;
