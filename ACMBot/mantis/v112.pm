#!/usr/bin/perl

package ACMBot::mantis::v112;

use strict;

sub new
{
	my $proto = shift;
	my $class = ( ref( $proto ) or $proto );

	my %args = @_;

	my $self = { ARGV => \%args,
		     db => undef,
		     trim => sub
		     {
		             my $val = shift;
		             $val =~ s/^\s+|\s+$//g;
		             return $val;
		     } };

	bless( $self, $class );

	$self -> { db } = $self -> { ARGV } -> { 'dbh' };

	return $self;
}

sub get_messages_for_ticket
{
	my $self = shift;
	my $dbh = $self -> { db };

	unless( defined $dbh )
	{
		return 0;
	}

	my %args = @_;

	my $sql = sprintf( 'select u.username, u.realname, bnt.note, bn.id as bnid, b.id as bid, bnt.id, b.summary, bn.last_modified
			    from mantis_bug_table b, mantis_bugnote_table bn, mantis_bugnote_text_table bnt, mantis_user_table u
			    where b.id=%d and bn.bug_id=b.id and bnt.id=bn.bugnote_text_id and u.id=bn.reporter_id and bn.last_modified>%s and bn.id>=%d;',
			    int( $self -> { trim } -> ( $args{ 'bug' } ) ),
			    $args{ 'last' } -> { 'time' } ? $dbh -> quote( $args{ 'last' } -> { 'time' } ) : 'NOW()',
#			    $dbh -> quote( ( $args{ 'last' } -> { 'time' } or '1970-01-01 00:00:01' ) ),
			    int( $self -> { trim } -> ( $args{ 'last' } -> { 'id' } ) ) );

#	print $sql . "\n";
	return $dbh -> multi_select( $sql );
}

sub check_user
{
	my $self = shift;
	my $dbh = $self -> { db };

	unless( defined $dbh )
	{
		return 0;
	}

	my %args = @_;

	my $record = $dbh -> select( sprintf( 'select id, password from mantis_user_table where username=%s;',
					      $dbh -> quote( $self -> { trim } -> ( $args{ 'username' } ) ) ) );

	unless( $record )
	{
		return 0;
	}

	return ( $record -> { 'password' } eq $self -> { trim } -> ( $args{ 'password' } ) ) ? $record -> { 'id' } : 0;
}

sub get
{
	my $self = shift;
	return $self -> get_messages_for_ticket( @_ );
}

1;
