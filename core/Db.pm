#!/usr/bin/perl

package ACMBot::core::Db;

use strict;

sub new
{
	my $proto = shift;

	my $class = ( ref( $proto ) or $proto );

	my $self = {};

	bless( $self, $class );

	return $self;
}

sub connect
{
	my $self = shift;
	return 1;
}

1;
