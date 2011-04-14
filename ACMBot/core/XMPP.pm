#!/usr/bin/perl

package ACMBot::core::XMPP;

use strict;

use Net::XMPP 'Client';

sub new
{
	my $proto = shift;
	my $class = ( ref( $proto ) or $proto );

	my %args = @_;

	my $self = { client => undef,
		     roster => undef,
		     ARGV => \%args };

	bless( $self, $class );

	unless( $self -> client -> Connected() )
	{
		$self = 0;
	}

	return $self;
}

sub connect
{
	my $self = shift;

	unless( defined $self -> { client } )
	{
		$self -> { client } = Net::XMPP::Client -> new( debuglevel => ( $self -> { ARGV } -> { jdebug } or 0 ) );

		$self -> { client } -> Connect( hostname       => $self -> { ARGV } -> { jhost },
						port           => $self -> { ARGV } -> { jport },
						connectiontype => $self -> { ARGV } -> { jctype },
						componentname  => $self -> { ARGV } -> { jdomain },
						tls            => $self -> { ARGV } -> { jtls } );

		my $sid = $self -> { client } -> { SESSION }{ id };

		$self -> { client } -> { STREAM } -> { SIDS } -> { $sid } -> { hostname } = $self -> { ARGV } -> { jdomain };

		$self -> { client } -> AuthSend( username => $self -> { ARGV } -> { juser },
						 password => $self -> { ARGV } -> { jpass },
						 resource => $self -> { ARGV } -> { jrsrc } );

		$self -> { client } -> PresenceSend();
		$self -> { roster } = $self -> { client } -> Roster();
	}

	return $self -> { client };
}

sub client
{
	my $self = shift;
	return $self -> connect( @_ );
}

sub disconnect
{
	my $self = shift;
	my $client = $self -> client();
	return $client -> Disconnect();
}

sub send
{
	my $self = shift;
	my %args = @_;

	return $self -> client -> MessageSend(  to       => $args{ 'to' },
						subject  => '',
						body     => $args{ 'body' },
						type     => 'chat',
						priority => 10  );
}

1;
