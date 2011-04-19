#!/usr/bin/perl

use strict;

package ACMBot;

use ACMBot::core;

my $core = ACMBot::core -> new( config => 'acmbot.conf' );

unless( $core )
{
	die 'fail :(';
}

$core -> bot -> client -> SetCallBacks( message => \&message_handler );
$core -> set_auth_callback( \&register_user );

while( defined $core -> bot -> client -> Process( 5 ) )
{
	1;
}

exit 0;

sub echo
{
	my ( $sid, $msg ) = @_;
	$core -> bot -> send( to => $msg -> GetFrom(), body => $msg -> GetBody() );
}

sub message_handler
{
	my ( $sid, $msg ) = @_;

	my $jid = $msg -> GetFrom( 'jid' ) -> GetJID( 'base' );
	my $cmd = $msg -> GetBody();

	$cmd =~ s/^\s+|\s+$//g;

	if( $cmd =~ m/^subscribe\s(\d+)$/gi )
	{
		if( &subscribe_to_bug( $jid, $1 ) )
		{
			$core -> bot -> send( to => $msg -> GetFrom(), body => 'Successfully subscribed.' );
		} else
		{
			$core -> bot -> send( to => $msg -> GetFrom(), body => 'Subscription failed.' );
		}
	} elsif( $cmd =~ m/^unsubscribe\s(\d+)$/gi )
	{
		if( &unsubscribe_from_bug( $jid, $1 ) )
		{
			$core -> bot -> send( to => $msg -> GetFrom(), body => 'Successfully unsubscribed.' );
		} else
		{
			$core -> bot -> send( to => $msg -> GetFrom(), body => 'Unsubscription failed.' );
		}
	}

	return 1;
}

sub register_user
{
	my ( $sid, $msg ) = @_;
	my $self = $ACMBot::core::Actual;
	my $jid = $msg -> GetFrom( 'jid' ) -> GetJID( 'base' );

	unless( $self -> db -> select( sprintf( 'select id from ac_bot_users where jabber=%s', $core -> db -> quote( $jid ) ) ) )
	{
		unless( $self -> db -> do( sprintf( 'insert into ac_bot_users (jabber) values (%s) ', $core -> db -> quote( $jid ) ) ) )
		{
			return 0;
		}
	}

	$self -> bot -> client -> Subscription( type => 'subscribe', to => $msg -> GetFrom() );

	return 1;
}

sub bind_user
{
	my ( $jid, $mantis_id ) = @_;

	my $usrrec = $core -> db -> select( sprintf( 'select id from ac_bot_users where jabber=%s', $core -> db -> quote( $jid ) ) );

	unless( $usrrec )
	{
		return 0;
	}

	unless( $core -> db -> do( sprintf( 'update ac_bot_users set mantis_id=%d where jabber=%s', $mantis_id, $core -> db -> quote( $jid ) ) ) )
	{
		return 0;
	}

	return 1;
}

sub subscribe_to_bug
{
	my ( $jid, $bug ) = @_;

	my $usrrec = $core -> db -> select( sprintf( 'select id from ac_bot_users where jabber=%s', $core -> db -> quote( $jid ) ) );
	my $bugrec = $core -> db -> select( sprintf( 'select users from ac_bot_prefs where bug_id=%d', $bug ) );

	unless( $usrrec )
	{
		return 0;
	}

	unless( $usrrec -> { 'mantis_id' } )
	{
		return 0;
	}

	if( $bugrec )
	{
		my @users = split( /\:/, $bugrec -> { 'users' } );

		unless( &in( $usrrec -> { 'id' }, @users ) )
		{
			push @users, $usrrec -> { 'id' };
		}

		unless( $core -> db -> do( sprintf( 'update ac_bot_prefs set users=%s where bug_id=%d', $core -> db -> quote( join( ':', @users ) ), $bug ) ) )
		{
			return 0;
		}
	} else
	{
		unless( $core -> db -> do( sprintf( 'insert into ac_bot_prefs (users, bug_id) values( %s, %d )', $core -> db -> quote( $usrrec -> { 'id' } ), $bug ) ) )
		{
			return 0;
		}
	}

	return 1;
}

sub unsubscribe_from_bug
{
	my ( $jid, $bug ) = @_;

	my $usrrec = $core -> db -> select( sprintf( 'select id from ac_bot_users where jabber=%s', $core -> db -> quote( $jid ) ) );
	my $bugrec = $core -> db -> select( sprintf( 'select users from ac_bot_prefs where bug_id=%d', $bug ) );

	unless( $usrrec )
	{
		return 0;
	}

	unless( $usrrec -> { 'mantis_id' } )
	{
		return 0;
	}

	my $result = 0;

	if( $bugrec )
	{
		my @users = split( /\:/, $bugrec -> { 'users' } );

		unless( &in( $usrrec -> { 'id' }, @users ) )
		{
			return 0;
		}
 
		@users = &arr_del( $usrrec -> { 'id' }, @users );

		unless( scalar @users )
		{
			$result = $core -> db -> do( sprintf( 'delete from ac_bot_prefs where bug_id=%d', $bug ) );
		} else
		{
			$result = $core -> db -> do( sprintf( 'update ac_bot_prefs set users=%s where bug_id=%d', $core -> db -> quote( join( ':', @users ) ), $bug ) );
		}
	}

	return $result;
}

sub get_subscription_info
{
	my $prefs = $core -> db -> multi_select( 'select * from ac_bot_prefs;' );

	unless( $prefs )
	{
		return 0;
	}

	my %users = ();

	foreach my $bug ( keys %$prefs )
	{
		my $last = $core -> mantis -> get( bug => $prefs -> { $bug } -> { 'bug_id' },
						   last => { map{ $_ => scalar $prefs -> { $bug } -> { 'last_msg_' . $_ } } ( 'time', 'id' ) } );

		unless( $last )
		{
			next;
		}

		my @msg = ();
		my $lastid = 0;

		foreach my $note ( keys %$last )
		{
			push @msg, { from => ( $last -> { $note } -> { 'realname' } or $last -> { $note } -> { 'username' } ),
				     note => $last -> { $note } -> { 'note' },
				     name => $last -> { $note } -> { 'summary' },
				     link => sprintf( $core -> config -> get( 'link' ), $prefs -> { $bug } -> { 'bug_id' } ) };

			if( $lastid < $note )
			{
				$lastid = $note;
			}
		}

		unless( scalar @msg )
		{
			next;
		}

		my @userlist = split( /\:/, $prefs -> { $bug } -> { 'users' } );

		foreach my $userid ( @userlist )
		{
			unless( defined $users{ $userid } )
			{
				$users{ $userid } = { jabber  => '',
						      msgdata => [] };
			}

			my $msgdata = $users{ $userid } -> { 'msgdata' };
			$users{ $userid } -> { 'msgdata' } = [ ( @$msgdata, @msg ) ];
		}

		unless( $core -> db -> do( sprintf( 'update ac_bot_prefs set last_msg_id=%d and last_msg_time=NOW() where id=%d;', $lastid, $bug ) ) )
		{
			return 0;
		}
	}

	{
		my $userdata = $core -> db -> multi_select( sprintf( 'select id, jabber from ac_bot_users where id in (%s);', join( ', ', keys %users ) ) );

		unless( $userdata )
		{
			return 0;
		}

		foreach my $userid ( keys %$userdata )
		{
			$users{ $userid } -> { 'jabber' } = $userdata -> { $userid } -> { 'jabber' };
		}
	}

	return \%users;
}

sub send_jabber_notification
{
	my $info = shift;

	unless( $core -> bot -> roster_update() )
	{
		return 0;
	}

	foreach my $userid ( keys %$info )
	{
		my $msgdata = $info -> { $userid } -> { 'msgdata' };
		my @jids    = $core -> bot -> get_addresses( $info -> { $userid } -> { 'jabber' } );

		unless( scalar @jids and scalar @$msgdata )
		{
			next;
		}

		foreach my $msg ( @$msgdata )
		{
			my $body = &form_msg( $msg );

			unless( $body )
			{
				next;
			}

			foreach my $jid ( @jids )
			{
				$core -> bot -> send( to => $jid, body => $body );
			}
		}
	}

	return 1;
}

sub form_msg
{
	my $msg = shift;
	my $output = '';

	return $output;
}

sub in
{
	my $search = shift;
	my @array = @_;
	my $result = 0;

	foreach my $element ( @array )
	{
		if( $element eq $search )
		{
			$result++;
			last;
		}
	}

	return $result;
}

sub arr_del
{
	my $search = shift;
	my @array = @_;

	if( &in( $search, @array ) )
	{
		for( my $i = 0; $i <= $#array; $i++ )
		{
			if( $array[ $i ] eq $search )
			{
				delete $array[ $i ];
				last;
			}
		}
	}

	return @array;
}

1;
