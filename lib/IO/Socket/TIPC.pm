package IO::Socket::TIPC;
use IO::Socket::TIPC::Sockaddr;
use strict;
use Carp;
use Socket;
use IO::Socket;
use Switch;
use Scalar::Util qw(looks_like_number);
use AutoLoader;
use Exporter;

our @ISA = qw(Exporter IO::Socket);

our $VERSION = '0.04';

=head1 NAME

IO::Socket::TIPC - Perl sockets for TIPC

=head1 SYNOPSIS

	use IO::Socket::TIPC;
	my $sock = IO::Socket::TIPC->new(
		Type => 'stream',
		Peer => '{1000,100}'
	);


=head1 DESCRIPTION

TIPC stands for Transparent Inter-Process Communication.  See
http://tipc.sf.net/ for details.

This perl module subclasses IO::Socket, in order to use TIPC sockets
in the customary (and convenient) Perl fashion.

=head1 EXPORT

None by default.

=head2 Exportable constants

  ":tipc" tag (defines from tipc.h):
  AF_TIPC
  PF_TIPC
  SOL_TIPC
  TIPC_ADDR_ID
  TIPC_ADDR_MCAST
  TIPC_ADDR_NAME
  TIPC_ADDR_NAMESEQ
  TIPC_CFG_SRV
  TIPC_CLUSTER_SCOPE
  TIPC_CONN_SHUTDOWN
  TIPC_CONN_TIMEOUT
  TIPC_CRITICAL_IMPORTANCE
  TIPC_DESTNAME
  TIPC_DEST_DROPPABLE
  TIPC_ERRINFO
  TIPC_ERR_NO_NAME
  TIPC_ERR_NO_NODE
  TIPC_ERR_NO_PORT
  TIPC_ERR_OVERLOAD
  TIPC_HIGH_IMPORTANCE
  TIPC_IMPORTANCE
  TIPC_LOW_IMPORTANCE
  TIPC_MAX_USER_MSG_SIZE
  TIPC_MEDIUM_IMPORTANCE
  TIPC_NODE_SCOPE
  TIPC_OK
  TIPC_PUBLISHED
  TIPC_RESERVED_TYPES
  TIPC_RETDATA
  TIPC_SRC_DROPPABLE
  TIPC_SUBSCR_TIMEOUT
  TIPC_SUB_NO_BIND_EVTS
  TIPC_SUB_NO_UNBIND_EVTS
  TIPC_SUB_PORTS
  TIPC_SUB_SERVICE
  TIPC_SUB_SINGLE_EVT
  TIPC_TOP_SRV
  TIPC_WAIT_FOREVER
  TIPC_WITHDRAWN
  TIPC_ZONE_SCOPE

  ":socktypes" tag (exports from Socket.pm):
  SOCK_STREAM
  SOCK_DGRAM
  SOCK_SEQPACKET
  SOCK_RDM

To get all of the above constants, say:

	use IO::Socket::TIPC ':all';

To get all of the tipc stuff, say:

	use IO::Socket::TIPC ':tipc';

To get only the socket stuff, say:

	use IO::Socket::TIPC ':socktypes';

To get only the constants you plan to use, say something like:

	use IO::Socket::TIPC qw(SOCK_RDM TIPC_NODE_SCOPE);

Despite supporting all the above constants, please note that some
effort was made so normal users won't actually need any of them.  For
instance, in place of the SOCK_* socktypes, you can just specify
"stream", "dgram", "seqpacket" or "rdm".  In place of the TIPC_*_SCOPE
defines, given to Sockaddr's B<Scope> parameter, you can simply say
"zone", "cluster" or "node".

=cut


sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    my $constname;
    our $AUTOLOAD;
    ($constname = $AUTOLOAD) =~ s/.*:://;
    croak "&IO::Socket::TIPC::constant not defined" if $constname eq 'constant';
    my ($error, $val) = constant($constname);
    if ($error) { $val = undef; } # undefined constants just return undef.
    {
	no strict 'refs';
	    *$AUTOLOAD = sub { $val };
    }
    goto &$AUTOLOAD;
}

=head1 CONSTRUCTOR

B<new> returns a TIPC socket object.  This object inherits from
IO::Socket, and thus inherits all the methods of that class.  

This module was modeled specifically after B<IO::Socket::INET>, and
shares some things in common with that class.  Specifically, the
B<Listen> parameter, the Peer* and Local* nomenclature, and the
behind-the-scenes calls to socket(), bind(), listen(), connect(), and
what have you.

Connection-based sockets (B<SOCK_STREAM> and B<SOCK_SEQPACKET>) come
in "listen" and "connect" varieties.  To create a listener socket,
specify B<Listen =E<gt> 1> in your parameter list.  You can bind a
name to the socket, by providing a parameter like B<LocalName> =>
'{4242, 100}'.  To create a connection socket, provide one or more
Peer* parameters.

All Local* parameters are passed directly to
IO::Socket::TIPC::Sockaddr->new(), minus the 'Local' prefix, and the
resulting sockaddr is passed to bind().  Similarly, all Peer*
parameters are passed directly to IO::Socket::TIPC::Sockaddr->new(),
minus the 'Peer' prefix, and the result is passed to connect().  The
keywords B<Local> and B<Peer> themselves become the first string
parameter to new(); see the IO::Socket::TIPC::Sockaddr documentation
for details.

Examples of connection-based socket use:

	# Create a server listening on Name {4242, 100}.
	$sock1 = IO::Socket::TIPC->new(
		SocketType => 'stream',
		Listen => 1,
		LocalAddrType => 'name',
		LocalType => 4242,
		LocalInstance => 100,
		LocalScope => 'zone',
	);

	# Connect to the above server
	$sock2 = IO::Socket::TIPC->new(
		SocketType => 'stream',
		PeerAddrType => 'name',
		PeerType => 4242,
		PeerInstance => 100,
		PeerDomain => '<0.0.0>',
	);

Or the short versions of the same thing:

	# Create a server listening on Name {4242, 100}.
	$sock1 = IO::Socket::TIPC->new(
		SocketType => 'seqpacket',
		Listen => 1,
		Local => '{4242, 100}',
		LocalScope => 'zone',
	);

	# Connect to the above server
	$sock2 = IO::Socket::TIPC->new(
		SocketType => 'seqpacket',
		Peer => '{4242, 100}',
	);



Connectionless sockets (B<SOCK_RDM> and B<SOCK_DGRAM>) have no concept
of connecting or listening, but may still be bind()ed to a B<Name> or
B<Nameseq>.  You can use B<LocalName> or B<LocalNameseq> parameters to
select a name or name-sequence to bind to.  As above, these parameters
internally become B<Name> and B<Nameseq> arguments to
IO::Socket::TIPC::Sockaddr->new(), and the result is passed to bind().

Since connectionless sockets are not linked to a particular peer, you
can use B<sendto> to send a packet to some peer with a given Name in
the network, and B<recvfrom> to receive replies from a peer in the
network who sends a packet to your B<Name>.  You can also use
B<Nameseq> to send multicast packets to *every* peer with a given
name.  Please see the TIPC project's B<Programmers_Guide.txt> document
for more details.

Examples of connectionless socket use:

	# Create a server listening on Name {4242, 100}.
	$sock1 = IO::Socket::TIPC->new(
		SocketType => 'rdm',
		Local => '{4242, 100}',
		LocalScope => 'zone',
	);

	# Create another server listening on Name {4242, 101}.
	$sock2 = IO::Socket::TIPC->new(
		SocketType => 'rdm',
		Local => '{4242, 101}',
		LocalScope => 'zone',
	);

	$data = "TAG!  You're 'it'.";

	# send a hello packet from sock2 to sock1
	$addr1 = IO::Socket::TIPC::Sockaddr->new("{4242, 100}");
	$sock2->sendto($addr1, $data);

	# receive that first hello packet
	$sender_addr = $sock1->recvfrom($rxdata, 256);

	# send a (multicast) packet from sock1 to sock2's, everywhere
	$maddr2 = IO::Socket::TIPC::Sockaddr->new("{4242, 101, 101}");
	$sock1->sendto($maddr2, "My brain hurts!");

=cut

sub new {
	# pass it down to IO::Socket
	my $class = shift;
	return IO::Socket::new($class,@_);
}

sub configure {
	# IO::Socket calls us back via this method call, from IO::Socket->new().
	my($socket, $args) = @_;
	my (%local, %peer, $local, $peer);
	# move Local* args into %local, Peer* args into %peer.
	# keys "Local" and "Peer" themselves go into $local and $peer.
	# These become arguments to IO::Socket::TIPC::Sockaddr->new().
	foreach my $key (sort keys %$args) {
		if($key =~ /^local/i) {
			my $newkey = substr($key,5);
			if(length($newkey)) {
				$local{$newkey} = $$args{$key};
			} else {
				$local = $$args{$key};
			}
			delete($$args{$key});
		}
		if($key =~ /^peer/i) {
			my $newkey = substr($key,4);
			if(length($newkey)) {
				$peer{$newkey} = $$args{$key};
			} else {
				$peer = $$args{$key};
			}
			delete($$args{$key});
		}
	}
	return undef unless fixup_args($args);
	return undef unless enforce_required_args($args);
	my $connectionless = 0;
	my $listener       = 0;
	my $connector      = (scalar keys %peer)  || (defined $peer);
	my $binder         = (scalar keys %local) || (defined $local);
	$listener = 1 if(exists($$args{Listen}) && $$args{Listen});
	unless(looks_like_number($$args{SocketType})) {
		my $fixed = 0;
		
		switch($$args{SocketType}) {
			case /stream/i    { $fixed = 1; $$args{SocketType} = SOCK_STREAM    }
			case /seqpacket/i { $fixed = 1; $$args{SocketType} = SOCK_SEQPACKET }
			case /rdm/i       { $fixed = 1; $$args{SocketType} = SOCK_RDM       }
			case /dgram/i     { $fixed = 1; $$args{SocketType} = SOCK_DGRAM     }
		}
		my $type = $$args{SocketType};
		croak "unknown SocketType $type!"
			unless $fixed;
		$connectionless = 1 if $$args{SocketType} == SOCK_RDM;
		$connectionless = 1 if $$args{SocketType} == SOCK_DGRAM;
	}
	croak "Connectionless socket types cannot listen(), but you've told me to Listen."
		if($connectionless && $listener);
	croak "Connectionless socket types cannot connect(), but you've given me a Peer address."
		if($connectionless && $connector);
	croak "Listener sockets cannot connect, but you've given me a Peer address."
		if($listener && $connector);
	croak "Connect()ing sockets cannot bind, but you've given me a Local address."
		if($connector && $binder);

	# If we've gotten this far, I figure everything is ok.
	# unless Sockaddr barfs, of course.
	$socket->socket(PF_TIPC(), $$args{SocketType}, 0)
		or croak "Could not create socket: $!";
	if($binder) {
		my $baddr;
		if(defined($local)) {
			$baddr = IO::Socket::TIPC::Sockaddr->new($local, %local);
		} else {
			$baddr = IO::Socket::TIPC::Sockaddr->new(%local);
		}
		$socket->bind($baddr->raw)
			or croak "Could not bind socket: $!";
	}
	if($connector) {
		my $caddr;
		if(defined($peer)) {
			$caddr = IO::Socket::TIPC::Sockaddr->new($peer, %peer);
		} else {
			$caddr = IO::Socket::TIPC::Sockaddr->new(%peer);
		}
		$socket->connect($caddr->raw)
			or croak "Could not connect socket: $!";
	}
	if($listener) {
		$socket->listen()
			or croak "Could not listen: $!";
	}
	return $socket;
}

# a "0" denotes an optional value.  a "1" is required.
my %valid_args = (
	Listen     => 0,
	SocketType => 1,
);

sub enforce_required_args {
	my $args = shift;
	foreach my $key (sort keys %$args) {
		if($valid_args{$key}) {
			# argument is required.
			unless(exists($$args{$key})) {
				# argument not provided!
				croak "argument $key is REQUIRED.";
			}
		}
	}
	return 1;
}

sub fixup_args {
	my $args = shift;
	# Validate hash-key arguments to IO::Socket::TIPC->new()
	foreach my $key (sort keys %$args) {
		if(!exists($valid_args{$key})) {
			# This key needs to be fixed up.  Search for it.
			my $lckey = lc($key);
			my $fixed = 0;
			foreach my $goodkey (sort keys %valid_args) {
				if($lckey eq lc($goodkey)) {
					# Found it.  Fix it up.
					$$args{$goodkey} = $$args{$key};
					delete($$args{$key});
					$fixed = 1;
					last;
				}
			}
			croak("unknown argument $key")
				unless $fixed;
		}
	}
	return 1;
}


=head1 METHODS

=head2 sendto(addr, message [, flags])

B<sendto> is used with connectionless sockets, to send a message to a given
address.  The addr parameter should be an IO::Socket::TIPC::Sockaddr object.

	my $addr = IO::Socket::TIPC::Sockaddr->new("{4242, 100}");
	$sock->sendto($addr, "Hello there!\n");

You may have noticed that B<sendto> and Perl's builtin B<send> do more or
less the same thing with the order of arguments changed.  The main reason to
use B<sendto> is because you can pass it a IO::Socket::TIPC::Sockaddr object
directly, where B<send> requires you to call its ->B<raw>() method to get at
the raw binary "struct sockaddr_tipc" data.  So, B<sendto> is just a matter of
convenience.

Ironically, this B<sendto> method calls perl's B<send> builtin, which in turn
calls the C B<sendto> function.

=cut

sub sendto {
	my ($self, $addr, $message, $flags) = @_;
	croak "sendto given an undef message" unless defined $message;
	croak "sendto given a non-address?"
		unless ref($addr) eq "IO::Socket::TIPC::Sockaddr";
	$flags = 0 unless defined $flags;
	return $self->send($message, $flags, $addr->raw());
}


=head2 recvfrom(buffer, length [, flags])

B<recvfrom> is used with connectionless sockets, to receive a message from
a peer.  It returns a IO::Socket::TIPC::Sockaddr object, containing the
address of the message's sender.  B<NOTE!>  You must pass a *REFERENCE* to
the buffer, since it will be written to.

	my $buffer;
	my $sender = $sock->recvfrom(\$buffer, 30);
	$sock->sendto($sender, "I got your message.");

You may have noticed that B<recvfrom> and Perl's builtin B<recv> do more or
less the same thing with the order of arguments changed.  The main reason to
use B<recvfrom> is because it will return a IO::Socket::TIPC::Sockaddr object,
where B<recv> just returns a binary blob containing the C "struct
sockaddr_tipc" data.

Ironically, this B<recvfrom> method calls perl's B<recv> builtin, which in
turn calls the C B<recvfrom> function.

=cut

sub recvfrom {
	# note: the $buffer argument is written to by recv().
	my ($self, $buffer, $length, $flags) = @_;
	$flags = 0 unless defined $flags;
	my $rv = $self->recv($_[1], $length, $flags);
	return IO::Socket::TIPC::Sockaddr->new_from_data($rv);
}



use XSLoader;
XSLoader::load('IO::Socket::TIPC', $VERSION);

IO::Socket::TIPC->register_domain(PF_TIPC());

my @TIPC_STUFF = ( qw(
	AF_TIPC PF_TIPC SOL_TIPC TIPC_ADDR_ID TIPC_ADDR_MCAST TIPC_ADDR_NAME
	TIPC_ADDR_NAMESEQ TIPC_CFG_SRV TIPC_CLUSTER_SCOPE TIPC_CONN_SHUTDOWN
	TIPC_CONN_TIMEOUT TIPC_CRITICAL_IMPORTANCE TIPC_DESTNAME
	TIPC_DEST_DROPPABLE TIPC_ERRINFO TIPC_ERR_NO_NAME TIPC_ERR_NO_NODE
	TIPC_ERR_NO_PORT TIPC_ERR_OVERLOAD TIPC_HIGH_IMPORTANCE TIPC_IMPORTANCE
	TIPC_LOW_IMPORTANCE TIPC_MAX_USER_MSG_SIZE TIPC_MEDIUM_IMPORTANCE
	TIPC_NODE_SCOPE TIPC_OK TIPC_PUBLISHED TIPC_RESERVED_TYPES TIPC_RETDATA
	TIPC_SRC_DROPPABLE TIPC_SUBSCR_TIMEOUT TIPC_SUB_NO_BIND_EVTS
	TIPC_SUB_NO_UNBIND_EVTS TIPC_SUB_PORTS TIPC_SUB_SERVICE TIPC_SUB_SINGLE_EVT
	TIPC_TOP_SRV TIPC_WAIT_FOREVER TIPC_WITHDRAWN TIPC_ZONE_SCOPE
) );
my @SOCK_STUFF = ( qw( SOCK_STREAM SOCK_DGRAM SOCK_SEQPACKET SOCK_RDM ) );

our @EXPORT    = qw();
our @EXPORT_OK = qw();

our %EXPORT_TAGS = ( 
	'all'       => [ @TIPC_STUFF, @SOCK_STUFF ],
	'tipc'      => [ @TIPC_STUFF ],
	'socktypes' => [ @SOCK_STUFF ],
);
Exporter::export_ok_tags('all');

1;
__END__

=head1 BUGS

Probably many.  Please report any bugs you find to the author.  A TODO file
exists, which lists known unimplemented and broken stuff.


=head1 SEE ALSO

IO::Socket, IO::Socket::TIPC::Sockaddr, http://tipc.sf.net/,
http://tipc.cslab.ericcson.net/, Programmers_Guide.txt.


=head1 AUTHOR

Mark Glines <mark-tipc@glines.org>


=head1 COPYRIGHT AND LICENSE

This module is licensed under a dual BSD/GPL license, the same terms as TIPC
itself.

=cut
