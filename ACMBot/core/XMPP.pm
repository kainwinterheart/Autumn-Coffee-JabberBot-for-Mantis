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
		     presence_db => {},
		     callbacks => {},
		     ARGV   => \%args };

	bless( $self, $class );

	if( defined $self -> { ARGV } -> { 'callbacks' } )
	{
		$self -> set_callbacks( ( %{ $self -> { ARGV } -> { 'callbacks' } }, ( '__flag__' => 1 ) ) );
	}

	unless( $self -> client -> Connected() )
	{
		$self = undef;
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

		unless( $self -> { client } -> Connected() )
		{
			$self -> { client } = undef;
			return undef;
		}

		$self -> { callbacks } -> { presence } = \&__update_presence_db;
		$self -> set_callbacks();

		my $sid = $self -> { client } -> { SESSION }{ id };

		$self -> { client } -> { STREAM } -> { SIDS } -> { $sid } -> { hostname } = $self -> { ARGV } -> { jdomain };

		$self -> { client } -> AuthSend( username => $self -> { ARGV } -> { juser },
						 password => $self -> { ARGV } -> { jpass },
						 resource => $self -> { ARGV } -> { jrsrc } );

		$self -> { client } -> PresenceSend();
		unless( $self -> roster_update() )
		{
			die 'Can\'t get roster.';
		}
	}

	unless( $self -> { client } -> Connected() )
	{
		$self -> { client } = undef;
	}

	return $self -> { client };
}

sub set_callbacks
{
	my ( $self, $result, $flag ) = ( shift, 1, undef );
	my %args = @_;

	if( defined $args{ '__flag__' } )
	{
		$flag = 1;
		delete $args{ '__flag__' };
	}

	foreach my $func ( keys %args )
	{
		$self -> { callbacks } -> { $func } = $args{ $func };
		$result = ( $result and defined $self -> { callbacks } -> { $func } );
	}

	unless( defined $flag )
	{
		$self -> { client } -> SetCallBacks( %{ $self -> { callbacks } } );
	}

	return $result;
}

sub client
{
	my $self = shift;
	return $self -> connect( @_ );
}

sub disconnect
{
	my $self = shift;

	if( defined $self -> { client } )
	{
		if( not $self -> { client } -> Connected() or $self -> { client } -> Disconnect() )
		{
			$self -> { client } = undef;
		}
	}

	return not defined $self -> { client };
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

sub roster_update
{
	my $self = shift;

	#unless( defined )
	{
		#my %proxy = $self -> { client } -> RosterGet();
		#$self -> { roster } = \%proxy;
		$self -> { client } -> RosterRequest();
		$self -> { roster } = $self -> { client } -> Roster();
	}

	#$self -> { roster } = $self -> { roster } -> RosterRequest();

#	foreach my $key ( keys %{ $self -> { roster } } )
#	{
#		print $key . "\n";
#	}

	return $self -> { roster };
}

sub get_addresses
{
	my ( $self, $jid ) = @_;
	return grep{ $_ } @{ $self -> { presence_db } -> { $jid } };
}

sub __handle_subscribe
{
	my ( $self, $sid, $msg ) = @_;
	my ( $core, $result ) = ( $ACMBot::core::Actual, 1 );

	if( defined $core -> { auth_callback } )
	{
		$result = $core -> { auth_callback } -> ( $sid, $msg );
	}

	return $result;
}

sub __update_presence_db
{
	my ( $sid, $msg ) = @_;
	my $self = $ACMBot::core::Actual -> bot();

	unless( $self and $sid and $msg )
	{
		return 0;
	}

	if( $msg -> GetType() eq 'subscribe' )
	{
		return $self -> __handle_subscribe( $sid, $msg );
	}

	my $jid  = $msg -> GetFrom();
	my $base = $msg -> GetFrom( 'jid' ) -> GetJID( 'base' );

	my $present = 0;

	my $hdb = $self -> { presence_db };

	unless( defined $hdb -> { $base } )
	{
		$hdb -> { $base } = [];
	}

	my @db = @{ $hdb -> { $base } };

	foreach my $db_jid ( @db )
	{
		if( $db_jid eq $jid )
		{
			$present++;
			last;
		}
	}

	unless( $present )
	{
		push @db, $jid;
		$hdb -> { $base } = [ @db ];
		$self -> { presence_db } = $hdb;
	}

	return defined $self -> { presence_db } -> { $base };
}

1;
