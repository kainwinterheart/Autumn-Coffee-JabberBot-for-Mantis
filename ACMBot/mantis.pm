#!/usr/bin/perl

package ACMBot::mantis;

use strict;

use ACMBot::mantis::v112;

sub new
{
	my $proto = shift;
	my $class = ( ref( $proto ) or $proto );

	my %args = @_;

	my $self = { ARGV => \%args,
		     actual => undef,
		     prep => sub
		     {
		             my $val = shift;
		             $val =~ s/^\s+|\s+$|\.|[a-zA-Z]//g;
		             return $val;
		     } };

	bless( $self, $class );

	my $cmd = 'ACMBot::mantis::v' . $self -> { prep } -> ( $self -> { ARGV } -> { 'version' } ) . ' -> new( dbh => $self -> { ARGV } -> { \'dbh\' } );';

	$self -> { actual } = eval( $cmd );

	return $self -> { actual };
}

1;
