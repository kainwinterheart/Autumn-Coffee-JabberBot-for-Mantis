#!/usr/bin/perl

use strict;

package ACMBot;

use ACMBot::core;

my $core = ACMBot::core -> new( config => 'acmbot.conf' );

unless( $core )
{
	die 'fail :(';
}

$core -> bot -> client -> SetCallBacks( message => \&cb );

# my $record = $core -> mantis -> get( bug => 2, last => { time => '1970-01-01 00:00:01' } );

while( defined $core -> bot -> client -> Process( 5 ) )
{
	1;
}

exit 0;

sub cb
{
	my ( $sid, $msg ) = @_;
	$core -> bot -> send( to => $msg -> GetFrom(), body => $msg -> GetBody() );
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

		my @userlist = split( /\:/, $prefs -> { $bug } -> { 'users' } );
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

1;