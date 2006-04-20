#!/usr/bin/perl

# Simple data sender.  Talks to recv.pl.  Connects, and sends all of its stdin
# down the link.  Disconnects when it gets an EOF (ctrl+d).

use IO::Socket::TIPC;

my $sock = IO::Socket::TIPC->new(
	SocketType => 'seqpacket',  # SOCK_SEQPACKET
	Peer       => '{4242, 100}' # Connect to any server bound to this name
);

my $stdin = \*STDIN;
while(my $line = $stdin->getline()) {
	$sock->print($line);
}
