#!/usr/bin/perl

use strict;

package ACMBot::test;

use ACMBot::core;

print "Connecting...\n";

my $core = ACMBot::core -> new( config => 'acmbot.conf' );

unless( $core )
{
	die 'fail :(';
}

$core -> bot -> client -> Connected() ? print "Connected.\n" : die 'Can\'t connect.';
# print $core -> bot -> client -> GetErrorCode() . "\n";

$core -> bot -> client -> SetMessageCallBacks( normal    => undef,
					       chat      => \&cb,
					       groupchat => undef,
					       headline  => undef,
					       error     => undef );

my $record = $core -> mantis -> get( bug => 2, last => { time => '1970-01-01 00:00:01' } );

foreach my $key ( sort{ $a <=> $b } ( keys %$record ) )
{
	my $row = $record -> { $key };

	foreach my $col ( keys %$row )
	{
		print $col . ' => ' . $row -> { $col } . "\n";
	}

	print "-------\n";
}

while( 1 )
{
	my $status = $core -> bot -> client -> Process( 5 );

	unless( defined $status )
	{
		last;
	}

#	sleep( 1 );
}

# $test = $test -> select( 'select count(*) as id from mantis_bug_table;' );

# print $test -> { id } . "\n";

exit 0;

sub cb
{
	my ( $sid, $msg ) = @_;
	$core -> bot -> send( to => $msg -> GetFrom(), body => $msg -> GetBody() );
}
