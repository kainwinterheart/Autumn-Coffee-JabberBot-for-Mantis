#!/usr/bin/perl

use strict;

package ACMBot;

use ACMBot::core;

my $core = ACMBot::core -> new( config => 'acmbot.conf', callbacks => { message => \&message_handler } );

unless( $core )
{
	die "Can't create Core.";
}

unless( $core -> set_auth_callback( \&register_user ) )
{
	die 'Callbacks cannot be set.';
}

my $start = time();
my $last = $start;

while( 1 )
{
	my $status = $core -> bot -> client -> Process( 5 );

	if( defined $status )
	{
		$last = time();
		if( ( $last - $start ) >= ( ( int( $core -> config -> get( 'timeout' ) ) or 5 ) * 60 ) )
		{
			my $data = &get_subscription_info();

			$start = $last;

			if( $data )
			{
				unless( &send_jabber_notification( $data ) )
				{
					print "ERROR: Can't send messages.\n";
				}
			} else
			{
				print "ERROR: Can't get subscription info.\n";
			}
		}
	} else
	{
		print "WARNING: Bot is not connected, trying to reconnect.\n";

		while( not $core -> bot -> disconnect() )
		{
			sleep 1;
		}

		while( not defined $core -> bot -> client )
		{
			print "NOTIFY: Reconnecting...\n";
			sleep 1;
		}

		while( not $core -> bot -> client -> Connected() )
		{
			sleep 1;
		}

		while( not $core -> db -> reconnect() or not $core -> mdb -> reconnect() )
		{
			sleep 1;
		}

		print "NOTIFY: Bot is online again.\n";
	}
}

exit 0;

sub echo
{
	my ( $sid, $msg ) = @_;

	my $text = sprintf( "I don't know what means you message \"%s\".\nIf you want to know what I can do for you - send me just a four letter:\nhelp\nAlso have a nice day. :)",
			    $msg -> GetBody() );

	$core -> bot -> send( to => $msg -> GetFrom(), body => $text );
}

sub message_handler
{
	my ( $sid, $msg ) = @_;

	my $jid = $msg -> GetFrom( 'jid' ) -> GetJID( 'base' );
	my $cmd = $msg -> GetBody();

	$cmd =~ s/^\s+|\s+$//g;

	unless( $cmd )
	{
		return 1;
	}

	if( $cmd =~ m/^subscribe\s(\d+)$/i )
	{
		if( &subscribe_to_bug( $jid, $1 ) )
		{
			$core -> bot -> send( to => $msg -> GetFrom(), body => 'Successfully subscribed.' );
		} else
		{
			$core -> bot -> send( to => $msg -> GetFrom(), body => 'Subscription failed.' );
		}
	} elsif( $cmd =~ m/^unsubscribe\s(\d+)$/i )
	{
		if( &unsubscribe_from_bug( $jid, $1 ) )
		{
			$core -> bot -> send( to => $msg -> GetFrom(), body => 'Successfully unsubscribed.' );
		} else
		{
			$core -> bot -> send( to => $msg -> GetFrom(), body => 'Unsubscription failed.' );
		}
	} elsif( $cmd =~ m/^auth\suser\s(.+?)\spass\s(.+?)$/i )
	{
		if( &bind_user( $jid, $1, $2 ) )
		{
			$core -> bot -> send( to => $msg -> GetFrom(), body => 'Successfully bound to Mantis user.' );
		} else
		{
			$core -> bot -> send( to => $msg -> GetFrom(), body => 'Binding to Mantis user failed.' );
		}
=item
	} elsif( $cmd =~ m/^debug$/i )
	{
		my $data = &get_subscription_info();
		if( $data )
		{
			unless( &send_jabber_notification( $data ) )
			{
				$core -> bot -> send( to => $msg -> GetFrom(), body => 'Can\'t send messages.' );
			}
		} else
		{
			$core -> bot -> send( to => $msg -> GetFrom(), body => 'Can\'t get subscription data.' );
		}
=cut
	} elsif( $cmd =~ m/^help$/i )
	{
		$core -> bot -> send( to => $msg -> GetFrom(), body => 'Help message is in progress. Sorry for that.' );
	} elsif( $cmd =~ m/^uptime$/i )
	{
		$core -> bot -> send( to => $msg -> GetFrom(), body => sprintf( 'Uptime is %d seconds.', $core -> uptime() ) );
	} else
	{
		&echo( $sid, $msg );
	}

	return 1;
}

sub register_user
{
	my ( $sid, $msg ) = @_;
	my $self = $ACMBot::core::Actual;
	my $jid = $msg -> GetFrom( 'jid' ) -> GetJID( 'base' );

	unless( $self -> db -> select( sprintf( 'select id from ac_bot_users where jabber=%s', $self -> db -> quote( $jid ) ) ) )
	{
		unless( $self -> db -> do( sprintf( 'insert into ac_bot_users (jabber) values (%s) ', $self -> db -> quote( $jid ) ) ) )
		{
			return 0;
		}
	}

	$self -> bot -> client -> Subscription( type => 'subscribe', to => $msg -> GetFrom() );
	$self -> bot -> roster_update();

	return 1;
}

sub bind_user
{
	my ( $jid, $user, $pass ) = @_;

	my $mantis_id = $core -> mantis -> check_user( username => $user, password => $pass );

	unless( $mantis_id )
	{
		return 0;
	}

	my $usrrec = $core -> db -> select( sprintf( 'select id from ac_bot_users where jabber=%s', $core -> db -> quote( $jid ) ) );

	unless( $usrrec )
	{
		return 0;
	}

	unless( $core -> db -> do( sprintf( 'update ac_bot_users set mantis_id=%d where id=%d', $mantis_id, $usrrec -> { 'id' } ) ) )
	{
		return 0;
	}

	return 1;
}

sub subscribe_to_bug
{
	my ( $jid, $bug ) = @_;

	my $usrrec = $core -> db -> select( sprintf( 'select id, mantis_id from ac_bot_users where jabber=%s', $core -> db -> quote( $jid ) ) );
	my $bugrec = $core -> db -> select( sprintf( 'select users from ac_bot_prefs where bug_id=%d', $bug ) );

	unless( $usrrec )
	{
		print "Can't get userid for $jid\n\n";
		return 0;
	}

	unless( $usrrec -> { 'mantis_id' } )
	{
		print "User is not bound.\n\n";
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

	my $usrrec = $core -> db -> select( sprintf( 'select id, mantis_id from ac_bot_users where jabber=%s', $core -> db -> quote( $jid ) ) );
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
			unless( int( $last -> { $note } -> { 'id' } ) )
			{
				next;
			}

			push @msg, { from => ( $last -> { $note } -> { 'realname' } or $last -> { $note } -> { 'username' } ),
				     note => $last -> { $note } -> { 'note' },
				     name => $last -> { $note } -> { 'summary' },
				     link => sprintf( $core -> config -> get( 'link' ), $prefs -> { $bug } -> { 'bug_id' } ) };

			if( $lastid < $last -> { $note } -> { 'id' } )
			{
				$lastid = $last -> { $note } -> { 'id' };
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

		unless( $core -> db -> do( sprintf( 'update ac_bot_prefs set last_msg_id=%d, last_msg_time=NOW() where id=%d;', $lastid, $bug ) ) )
		{
			return 0;
		}
	}

	if( scalar keys %users )
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

	unless( $core -> bot -> dont_sleep() )
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

	unless( $msg -> { 'from' } and $msg -> { 'name' } )
	{
		return '';
	}

	my $output = sprintf( "%s sent you a message about \"%s\" ticket. Here's the message:\n\n%s\n\nLink to the ticket: %s",
			      $msg -> { 'from' }, $msg -> { 'name' }, $msg -> { 'note' }, $msg -> { 'link' } );

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
	my @new_array = ();

	if( &in( $search, @array ) )
	{
		for( my $i = 0; $i <= $#array; $i++ )
		{
			unless( $array[ $i ] eq $search )
			{
				push @new_array, $array[ $i ];
			}
		}
	}

	return @new_array;
}

1;
