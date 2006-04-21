#!/usr/bin/perl

# Simple data receiver.  Accepts data from clients, and prints it to stdout.
# Can only handle one client at a time.
# 
# WARNING: If you have more than one of these running on your network, send.pl
# might connect to a server other than yours.  See the documentation for scopes
# and domains, for details.

use IO::Socket::TIPC;

my $sock = IO::Socket::TIPC->new(
	Listen     => 1,             # This makes us a server
	SocketType => 'seqpacket',   # SOCK_SEQPACKET
	Local      => '{4242, 100}', # This is the name we bind() to
	LocalScope => 'zone',        # This affects where clients can connect from
);

while(1) {
	my $client = $sock->accept();
	while(my $line = $client->getline()) {
		print($line);
	}
}