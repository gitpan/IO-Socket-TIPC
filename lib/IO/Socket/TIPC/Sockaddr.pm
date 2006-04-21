package IO::Socket::TIPC::Sockaddr;
use strict;
use warnings;
use Carp;
use Scalar::Util qw(looks_like_number);
use Switch;

=head1 NAME

IO::Socket::TIPC::Sockaddr - struct sockaddr_tipc object

=head1 SYNOPSIS

	use IO::Socket::TIPC::Sockaddr;


=head1 DESCRIPTION

TIPC Sockaddrs are used with TIPC sockets, to specify local or remote
endpoints for communication.  They are used in the bind(), connect(),
sendto() and recvfrom() calls.

=cut


# Virtually this whole file is just hand-holding for the caller's benefit.
# 
# You can pass it strings like Id => "<a.b.c:d>", or Nameseq => "{a,b,c}".
# You can pass it the pieces, like AddrType => 'name', Type => 4242, Instance => 1.
# You can pass it a mixture of the two, like Id => "<a.b.c>", Ref => 8295.
# You can even omit the AddrType parameter, it'll guess from the other args.

# Passing the pieces (and specifying the AddrType) is the most efficient way to
# use this module, but not the most convenient, so other options exist.


sub divine_address_type {
	my $args = shift;
	# try to figure out what type of address this is.
	if(exists($$args{Type})) {
		if(exists($$args{Instance})) {
			$$args{AddrType} = 'name';
		}
		elsif(exists($$args{Lower})) {
			$$args{AddrType} = 'nameseq';
			$$args{Upper} = $$args{Lower}
				unless exists $$args{Upper};
		}
		elsif(exists($$args{Upper})) {
			$$args{AddrType} = 'nameseq';
			$$args{Lower} = $$args{Upper}
				unless exists $$args{Lower};
		}
	} elsif(exists($$args{Ref})) {
		$$args{AddrType} = 'id';
	} else {
		croak("could not guess AddrType - please specify it");
	}
	return 1;
}

my %valid_args = (
	'AddrType' => [qw(id name nameseq)], # 'id', 'name', or 'nameseq'
	'Zone'     => [qw(id             )], # <A.b.c:d>
	'Cluster'  => [qw(id             )], # <a.B.c:d>
	'Node'     => [qw(id             )], # <a.b.C:d>
	'Ref'      => [qw(id             )], # <a.b.c:D>
	'Id'       => [qw(id             )], # <A.B.C> (string or uint32) or <A.B.C:D> (string)
	'Type'     => [qw(   name nameseq)], # {A,b} or {A,b,c}
	'Instance' => [qw(   name        )], # {a,B}
	'Name'     => [qw(   name        )], # {A,B} (string)
	'Lower'    => [qw(        nameseq)], # {a,B,c}
	'Upper'    => [qw(        nameseq)], # {a,b,C}
	'Nameseq'  => [qw(        nameseq)], # {A,B,C} (string)
	'Scope'    => [qw(   name nameseq)], # TIPC_*_SCOPE, for binding, how far to advertise a name
	'Domain'   => [qw(   name        )], # tipc_addr, connect/sendto, how far to search for a name
);
	
sub validate_args_for_address_type {
	my $args = shift;
	my $addrtype = $$args{AddrType};
	# Validate hash-key arguments for this address type
	foreach my $key (sort keys %$args) {
		my $ref = $valid_args{$key};
		die "got here ($key)" unless defined $ref;
		my %valid = map { $_ => 1 } (@$ref);
		croak("argument $key not valid for AddrType $addrtype")
			unless exists($valid{$addrtype});
	}
	return 1;
}

sub fixup_hash_names {
	my $args = shift;
	# Validate hash-key arguments to IO::Socket::TIPC::Sockaddr->new()
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

sub string_parsing_stuff {
	my $args = shift;
	my %details;
	if(exists($$args{Id})) {
		# just in case the user did Id => '<1.2.3>', Ref => 4, pass in the Ref
		$details{Ref} = $$args{Ref} if exists $$args{Ref};
		return undef unless parse_string(\%details,$$args{Id});
		$$args{Zone}    = $details{Zone};
		$$args{Cluster} = $details{Cluster};
		$$args{Node}    = $details{Node};
		$$args{Ref}     = $details{Ref} if exists($details{Ref});
	} elsif(exists($$args{Name})) {
		return undef unless parse_string(\%details,$$args{Name});
		$$args{Type}     = $details{Type};
		$$args{Instance} = $details{Instance};
	} elsif(exists($$args{Nameseq})) {
		return undef unless parse_string(\%details,$$args{Nameseq});
		$$args{Type}     = $details{Type};
		$$args{Lower}    = $details{Lower};
		$$args{Upper}    = $details{Upper};
	}
	if(exists($details{AddrType})) {
		$$args{AddrType} = $details{AddrType} unless exists $$args{AddrType};
	}
	return 1;
}

my %addr_prereqs = (
	'id'      => [qw(Zone Cluster Node Ref)],
	'name'    => [qw(Scope Type Instance)],
	'nameseq' => [qw(Scope Type Lower Upper)],
);

sub check_prereqs_for_address_type {
	my $args = shift;
	my $addrtype = $$args{AddrType};
	my $ref = $addr_prereqs{$addrtype};
	croak "got here ($addrtype)" unless defined $ref;
	foreach my $key (@$ref) {
		croak "addrtype $addrtype requires a $key value"
			unless exists($$args{$key});
	}
	1;
}


=head1 CONSTRUCTOR

	new ( "string", key=>value, key=>value... )
	new ( key=>value, key=>value... )
	new_from_data ( $binary_blob_of_struct_sockaddr_tipc )

Creates an "IO::Socket::TIPC::Sockaddr" object, which is really just a
bunch of fluff to manage C "struct sockaddr_tipc" values in an
intuitive fashion.

The B<new>() constructor takes a series of Key => Value pairs as
arguments.  It needs an B<AddrType> argument, but it can often guess
this from the other values you've passed, because different address
types take a different set of params.  B<new>() can also take a text
string as its first (or only) argument, which should be a stringized
form of the address you want.  B<new> can also guess the B<AddrType>
from context (in string form or from the other attributes), if you
provide enough.

If you intend to use a TIPC sockaddr for a local port name or nameseq,
you should provide the B<Scope> parameter, to specify how far away
connections can come in from.  Please see the TIPC
Programmers_Guide.txt for details.  The default is B<TIPC_NODE_SCOPE>.
You can specify the B<Scope> as one of the TIPC_*_SCOPE constants, or
as a string, "node", "cluster" or "zone".

If you intend to use a "name"-type sockaddr, you might also want to
provide the B<Domain> parameter, to specify how TIPC should search for
the peer.  This param takes a TIPC address as its argument, which can
be a string, like "<1.2.3>", or a number, like 0x01002003.  Please see
the TIPC Programmers_Guide.txt for details.  The default is "<0.0.0>",
which means, "gimme the closest node you can find, and search the
whole network if you have to".

Sockaddrs can be broken down into 3 address-types, "name", "nameseq"
and "id". Again, the Programmers_Guide.txt explains this stuff much
better than I ever could, you should read it.

=head2 name

You can use "name" sockets in the following manner:

	$name = IO::Socket::TIPC::Sockaddr->new(
		AddrType => 'name',
		Type => 4242,
		Instance => 1005);

Or

	$name = IO::Socket::TIPC::Sockaddr->new(
		AddrType => 'name',
		Name => '{4242, 1005}');

Or, even

	$name = IO::Socket::TIPC::Sockaddr->new('{4242, 1005}');

With all address types, the stringify() method will return something
readable.

	$string = $name->stringify();
	# stringify returns "{4242, 1005}"


=head2 nameseq

You can use "nameseq" sockets in the following manner:

	$nameseq = IO::Socket::TIPC::Sockaddr->new(
		AddrType => 'nameseq',
		Type     => 4242,
		Lower    => 100,
		Upper    => 1000);

Or, more simply,

	$nameseq = IO::Socket::TIPC::Sockaddr->new(
		AddrType => 'nameseq',
		Name     => '{4242, 100, 1000}');

Or even just

	$nameseq = IO::Socket::TIPC::Sockaddr->new('{4242, 100, 1000}');

If you don't specify an B<Upper>, it defaults to the B<Lower>.  If you
don't specify a B<Lower>, it defaults to the B<Upper>.  You must
specify at least one.

	$nameseq = IO::Socket::TIPC::Sockaddr->new(
		AddrType => 'nameseq',
		Type => 4242,
		Lower => 100);

With all address types, the stringify() method will return something
readable.

	$string = $nameseq->stringify();
	# stringify returns "{4242, 100, 100}"


=head2 id

You can use "id" sockets in the following manner:

	$id = IO::Socket::TIPC::Sockaddr->new(
		AddrType => 'id',
		Zone     => 1,
		Cluster  => 2,
		Node     => 3,
		Ref      => 5000);

Or, more simply,

	$id = IO::Socket::TIPC::Sockaddr->new(
		AddrType => 'id',
		Id       => "<1.2.3>",
		Ref      => 5000);

Or, more simply,

	$id = IO::Socket::TIPC::Sockaddr->new(
		AddrType => 'id',
		Id       => "<1.2.3:5000>");

Or even just

	$id = IO::Socket::TIPC::Sockaddr->new("<1.2.3:5000>");
		
With all address types, the stringify() method will return something
readable.

	$string = $id->stringify();
	# stringify returns "<1.2.3:5000>"

=cut




sub new {
	my $package = shift;
	my %args = ();
	if(@_) {
		if(scalar @_ & 1) {
			return undef unless parse_string(\%args, shift);
		}
		%args = (%args, @_);
	}
	# sanity-check input, correct capitalization, make sure all keys are valid
	return undef unless fixup_hash_names(\%args);
	# handle things like Id => '<1.2.3:4>'
	return undef unless string_parsing_stuff(\%args); 
	unless(exists($args{AddrType})) {
		return undef unless divine_address_type(\%args);
	}
	# check that we don't have any extra values.  (like Name, for an "id" addr)
	return undef unless validate_args_for_address_type(\%args);
	# fill in some optional stuff
	if($args{AddrType} eq 'name') {
		if(exists($args{Domain})) {
			unless(looks_like_number($args{Domain})) {
				my $href = {};
				parse_string($href,$args{Domain});
				croak "Domain string should be an id!"
					unless $$href{AddrType} eq 'id';
				$args{Domain} = pack_tipc_addr(@$href{'Zone','Cluster','Node'});
			}
		} else {
			$args{Domain} = 0;
		}
	}
	if(exists($args{Scope})) {
		my $scope = $args{Scope};
		my %valid_scopes = (
			IO::Socket::TIPC::TIPC_ZONE_SCOPE() => 1,
			IO::Socket::TIPC::TIPC_CLUSTER_SCOPE() => 1,
			IO::Socket::TIPC::TIPC_NODE_SCOPE() => 1,
		);
		unless(exists($valid_scopes{$scope})) {
			switch($scope) {
				case 'zone' {
					$args{Scope} = IO::Socket::TIPC::TIPC_ZONE_SCOPE();
				}
				case 'cluster' {
					$args{Scope} = IO::Socket::TIPC::TIPC_CLUSTER_SCOPE();
				}
				case 'node' {
					$args{Scope} = IO::Socket::TIPC::TIPC_NODE_SCOPE();
				}
			}
		}
		$scope = $args{Scope};
		croak("invalid Scope $scope")
			unless exists $valid_scopes{$scope};
	} else {
		$args{Scope}  = IO::Socket::TIPC::TIPC_NODE_SCOPE();
	}

	# check that we do have the arguments we need.
	return undef unless check_prereqs_for_address_type(\%args);
	$args{_sockaddr} = _create();
	_fill_tipc_common(@args{'_sockaddr','Scope'});
	switch($args{AddrType}) {
		my $valid = 0;
		case 'id' {
			_fill_tipc_id_pieces(@args{"_sockaddr","Ref","Zone","Cluster","Node"});
			$valid = 1;
		}
		case 'name' {
			_fill_tipc_name(@args{"_sockaddr","Type","Instance","Domain"});
			$valid = 1;
		}
		case 'nameseq' {
			_fill_tipc_nameseq(@args{"_sockaddr","Type","Upper","Lower"});
			$valid = 1;
		}
	}
	return bless({%args},$package);
}

sub new_from_data {
	my ($package, $data) = @_;
	my $addr = $package->new(_stringify($data));
	# FIXME: the sockaddr itself will retain Scope/Domain info, since we're
	# keeping the same bits we started with.  However, the informational hash
	# stuff will be missing these fields.
	$$addr{_sockaddr} = $data;
	return $addr;
}


=head1 METHODS

=head2 stringify()

B<stringify> returns a string representing the sockaddr.  These
strings are the same as the ones used in the TIPC documentation,
see Programmers_Guide.txt.  Depending on the address type, it will
return something that looks like one of:

	"<1.2.3:4>"        # ID, addr = 1.2.3, ref = 4
	"{4242, 100}"      # NAME, type = 4242, instance = 100
	"{4242, 100, 101}" # NAMESEQ, type = 4242, range 100-101

Note that these strings are intended for use as shorthand, with
someone familiar with TIPC.  They do not include all the (potentially
important) fields of the sockaddr structure.  In particular, they are
missing the B<Scope> and B<Domain> fields, which affect how far away
binding/connecting may occur for names and nameseqs.  If you need to
store an address for reuse, you are better off reusing the Sockaddr
object itself, rather than storing one of these strings.

=cut

sub stringify {
	my $self = shift;
	return _stringify($$self{_sockaddr});
}

=head2 raw()

B<raw> returns a string containing the packed sockaddr_tipc structure.
It is suitable for passing to bind(), connect(), sendto(), and so
forth.

	$sock->sendto($addr->raw(), "Hello!  My brain hurts.");

B<bits> is an alias for B<raw>.

=cut

sub raw {
	my $self = shift;
	return $$self{_sockaddr};
}
sub bits { return raw(@_) }

=head1 HELPER ROUTINES

=head2 unpack_tipc_addr(int)

Unpacks a TIPC address (integer) into its constituent components.  Returns a
hash reference containing the components of the address.

	my $href = unpack_tipc_addr(0x01002003);
	printf("<%i.%i.%i>\n",
	       @$href{'Zone', 'Cluster', 'Node'}); # prints <1.2.3>

=cut

sub unpack_tipc_addr {
	my $addr = shift;
	return {
		Zone    => ($addr >> 24) & 0x000000ff, # 8 bits
		Cluster => ($addr >> 12) & 0x00000fff, # 12 bits
		Node    => ($addr      ) & 0x00000fff, # 12 bits
	};
}

=head2 pack_tipc_addr(zone, cluster, node)

Packs components of a TIPC address into a real address (integer).  Takes the
zone, cluster and node components as arguments, in that order.  Returns the
address.

	my $addr = pack_tipc_addr(1, 2, 3);
	printf("%x\n", $addr); # prints 0x01002003

=cut

sub pack_tipc_addr {
	my ($zone, $cluster, $node) = @_;
	$zone     &= 0xff;
	$cluster  &= 0xfff;
	$node     &= 0xfff;
	$zone    <<= 24;
	$cluster <<= 12;
	return $zone | $cluster | $node;
}


=head2 parse_string(hashref, string)

Given a string that looks like "<1.2.3:4>", "<1.2.3>", "{1, 2}", or
"{1, 2, 3}", chop it into its components.  Puts the components into
appropriately named keys in hashref, like B<Zone>, B<Cluster>,
B<Node>, B<Ref>, B<Type>, B<Instance>, B<Upper>, B<Lower>.  It also
gives you the B<AddrType> of the string you passed.  Returns 1 on
success, croaks on error.

	my $href = {};
	parse_string($href, "<1.2.3:4>");
	printf("Address <%i.%i.%i:%i> is of type %s\n",
		 @$href{'Zone', 'Cluster', 'Node', 'Ref', 'AddrType'});
	# prints "Address <1.2.3:4> is of type id\n"

This is a function which B<new>() uses internally, to turn whatever
garbage it's been given into some values it can actually use.  You
don't have to call it directly, unless you want to use the same
parser for some other reason, like input checking.

=cut

sub parse_string {
	my ($args, $string) = @_;
	# we got a string.  we accept the following types of string:
	# ID:       '<a.b.c>'    (REF=0)
	# ID (dec): '12345'      (REF=0)
	# ID (hex): '0x01002003' (REF=0)
	# ID+REF:   '<a.b.c:d>' 
	# NAME:     '{a,b}'
	# NAMESEQ:  '{a,b,c}'
	my $valid = 0;
	# handle string ID+REF or string ID
	if($string =~ /^<(\d+)\.(\d+)\.(\d+)(:(\d+))?>$/) {
		$$args{AddrType} = 'id';
		$$args{Zone}     = $1;
		$$args{Cluster}  = $2;
		$$args{Node}     = $3;
		$$args{Ref}      = $5 if defined $5;
		$$args{Ref}      = 0 unless defined $$args{Ref};
		$valid           = 1;
	}
	# handle decimal ID
	if($string =~ /^(\d+)$/) {
		%$args           = (%$args, %{unpack_tipc_addr($1+0)});
		$$args{AddrType} = 'id';
		$valid           = 1;
	}
	# handle hex ID
	if($string =~ /^0x([0-9a-fA-F]{1,8})$/) {
		%$args           = (%$args, %{unpack_tipc_addr(hex($1))});
		$$args{AddrType} = 'id';
		$valid           = 1;
	}
	
	# handle string NAME
	if($string =~ /^\{(\d+),\s*(\d+)\}$/) {
		$$args{AddrType} = 'name';
		$$args{Type}     = $1;
		$$args{Instance} = $2;
		$valid           = 1;
	}
	# handle string NAMESEQ
	if($string =~ /^\{(\d+),\s*(\d+),\s*(\d+)\}$/) {
		$$args{AddrType} = 'nameseq';
		$$args{Type}     = $1;
		$$args{Lower}    = $2;
		$$args{Upper}    = $3;
		$valid           = 1;
	}
	croak("string argument '$string' is not valid TIPC address.")
		unless($valid);
	return 1;
}

1;
__END__

=head1 BUGS

Probably many.  Please report any bugs you find to the author.  A TODO file
exists, which lists known unimplemented and broken stuff.


=head1 SEE ALSO

IO::Socket, Socket, IO::Socket::TIPC,
http://tipc.sf.net/, http://tipc.cslab.ericcson.net/, Programmers_Guide.txt.


=head1 AUTHOR

Mark Glines <mark-tipc@glines.org>


=head1 COPYRIGHT AND LICENSE

This module is licensed under a dual BSD/GPL license, the same terms as TIPC
itself.
