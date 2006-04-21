use strict;
use warnings;
use IO::Socket::TIPC;
use Test::More;
my $tests;
BEGIN { $tests = 0; };

my $Type = 0x73570000 + $$;

# Long API.
my $csock = IO::Socket::TIPC->new(
	SocketType => 'rdm',
	LocalAddrType => 'name',
	LocalType => $Type,
	LocalInstance => 73570302,
	LocalScope => 'node',
);
ok(defined($csock), "Create an rdm socket");
if(fork()) {
	# server (and test) process.
	# SOCKET CREATION.
	my $ssock = IO::Socket::TIPC->new(
		SocketType => 'rdm',
		LocalAddrType => 'name',
		LocalType => $Type,
		LocalInstance => 73570301,
		LocalScope => 'node',
	);
	ok(defined($ssock), "Create an rdm socket");
	alarm(5);
	my $caddr = IO::Socket::TIPC::Sockaddr->new(
		AddrType => 'name',
		Type => $Type,
		Instance => 73570302,
	);
	$ssock->sendto($caddr, "Hello there!\n");
	my $string;
	my $servaddr = $ssock->recvfrom($string, 13);
	like($string, qr/Well, hello/, "Client replied to our message");
} else {
	# child process
	alarm(5);
	my $string;
	my $servaddr = $csock->recvfrom($string, 13);
	if($string =~ /Hello/) {
		$csock->sendto($servaddr, "Well, hello!\n");
	}
	exit(0);
}
BEGIN { $tests += 3; }


# Shorthand version of the same thing.
$csock = IO::Socket::TIPC->new(
	SocketType => 'rdm',
	Local => "{$Type, 73570304}",
);
ok(defined($csock), "Create an rdm socket");if(fork()) {
	# server (and test) process.
	# SOCKET CREATION.
	my $ssock = IO::Socket::TIPC->new(
		SocketType => 'rdm',
		Local => "{$Type, 73570303}",
	);
	ok(defined($ssock), "Create an rdm socket");
	alarm(5);
	my $caddr = IO::Socket::TIPC::Sockaddr->new("{$Type, 73570304}");
	$ssock->sendto($caddr, "Hello there!\n");
	my $string;
	my $servaddr = $ssock->recvfrom($string, 13);
	like($string, qr/You again/, "Client replied to our message");
} else {
	# child process
	alarm(5);
	my $string;
	my $servaddr = $csock->recvfrom($string, 13);
	if($string =~ /Hello/) {
		$csock->sendto($servaddr, "You again??!\n");
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
