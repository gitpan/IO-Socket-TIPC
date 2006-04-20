use strict;
use warnings;
use IO::Socket::TIPC;
use Test::More;
my $tests;
BEGIN { $tests = 0; };

my $Type = 0x73570000 + $$;

# Long API.
if(fork()) {
	# server (and test) process.
	# SOCKET CREATION.  almost straight from the POD examples...
	# Create a server
	my $sock1 = IO::Socket::TIPC->new(
		SocketType => 'seqpacket',
		Listen => 1,
		LocalAddrType => 'name',
		LocalType => $Type,
		LocalInstance => 73570201,
		LocalScope => 'node',
	);
	ok(defined($sock1), "Create a server socket");
	alarm(5);
	my $sock2 = $sock1->accept();
	ok(defined($sock2), "Client connected");
	alarm(5);
	$sock2->print("Hello there!\n");
	like($sock2->getline(), qr/hello yourself/, "Client replied to our message");
} else {
	# child process
	# give the server time to set up
	sleep(1);
	# Connect to the above server
	my $sock1 = IO::Socket::TIPC->new(
		SocketType => 'seqpacket',
		PeerAddrType => 'name',
		PeerType => $Type,
		PeerInstance => 73570201,
		PeerDomain => '<0.0.0>',
	);
	my $string = $sock1->getline();
	if($string =~ /Hello/) {
		$sock1->print("Well, hello yourself!\n");
	}
	exit(0);
}
BEGIN { $tests += 3; }

# Same thing again, this time with the short API.
if(fork()) {
	# server (and test) process.
	# SOCKET CREATION.  almost straight from the POD examples...
	# Create a server
	my $sock1 = IO::Socket::TIPC->new(
		SocketType => 'seqpacket', Listen => 1, Local => "{$Type, 73570202}");
	ok(defined($sock1), "Create a server socket");
	alarm(5);
	my $sock2 = $sock1->accept();
	ok(defined($sock2), "Client connected");
	alarm(5);
	$sock2->print("Hello there!\n");
	like($sock2->getline(), qr/you again/i, "Client replied to our message");
} else {
	# child process
	# give the server time to set up
	sleep(1);
	# Connect to the above server
	my $sock1 = IO::Socket::TIPC->new(
		SocketType => 'seqpacket', Peer => "{$Type, 73570202}");
	my $string = $sock1->getline();
	if($string =~ /Hello/) {
		$sock1->print("You again?\n");
	}
	exit(0);
}
BEGIN { $tests += 3; }


BEGIN {
	if(`grep ^TIPC /proc/net/protocols`) {
		plan tests => $tests;
	} else {
		plan skip_all => 'you need to modprobe tipc';
	}
}
