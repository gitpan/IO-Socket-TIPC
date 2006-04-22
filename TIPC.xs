#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "tipc.h"

#ifndef PF_TIPC
# ifdef AF_TIPC
#  define PF_TIPC AF_TIPC
# endif
#endif

/* We toss these around a LOT.  Use a typedef, to keep it concise. */
typedef struct sockaddr_tipc SAT;

/* input-checking for passing a struct sockaddr_tipc from within an SvRV*. */
SAT *_tipc_sanity_check(SV *rv) {
	SV *sv;
	if(SvTYPE(rv) == SVt_RV)
		sv = SvRV(rv);
	else
		croak("Sockaddr methods work on blessed references to raw data.");
	if(sv_len(sv) != 16)
		croak("Sockaddr method called with non-sockaddr argument! (length is %i)",sv_len(sv));
	else {
		SAT *sat = (void*)SvPV_nolen(sv);
		if(sat->family != AF_TIPC)
			croak("Sockaddr family mismatch: not AF_TIPC!");
		return sat;
	}
	return NULL;
}

/* in the following code, internal functions are prefixed with "_tipc_".
 * Stuff intended for direct user use does not have this prefix. */

#include "const-c.inc"

MODULE = IO::Socket::TIPC		PACKAGE = IO::Socket::TIPC

INCLUDE: const-xs.inc

MODULE = IO::Socket::TIPC		PACKAGE = IO::Socket::TIPC::Sockaddr

PROTOTYPES: ENABLE

=head1 THE SOCKADDR XS STUFF

What follows are some accessor functions for the sockaddr_tipc structure.
I could have simply done some pack()/unpack() statements in Perl code, but
that would break horribly if they ever changed the structure, resulting in
size mismatches and such.  This way it'll stay valid as long as they leave
a migration path.

Also note that these routines will break horribly if you call them with a
wrongly sized (clobbered, truncated, whatever) SV.  Calling code should be
careful to create the SV with _create(), and never write to it directly.
None of these functions are published directly, though the module's user
may be able to clobber the struct with vec and s/\0/1/ and the like.

=head1 OBJECT CREATION STUFF

=head2 SV *_tipc_create()

Create a blank buffer of the right length; set family to AF_TIPC, and return
the buffer wrapped up in a scalar.

=cut

SV *
_tipc_create()
  INIT:
	SAT sat;
	SV *sv, *rv;
  CODE:
	memset(&sat,0,sizeof(sat));
	sat.family = AF_TIPC;
	rv = newSV(0);
	sv = newSVrv(rv,"IO::Socket::TIPC::Sockaddr");
	sv_setpvn(sv, (void*)&sat, sizeof(sat));
	RETVAL = rv;
  OUTPUT:
	RETVAL

=head2 void _tipc_clear(SV *sv)

Wipe a buffer clean.  Memsets it to 0, then sets the family to AF_TIPC again.

=cut

void
_tipc_clear(sv)
	SV *sv
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	memset(sat,0,sizeof(SAT));
	sat->family = AF_TIPC;
  OUTPUT:
	sv

=head2 void _tipc_fill_common(SV *sv, char scope)

Fill in the fields which are common to all sockaddrs.  Turns out there's only
one common field; the scope.  This is an enum, use it with constants like
TIPC_NODE_SCOPE.

=cut

void
_tipc_fill_common(sv, scope)
	SV *sv
	unsigned char scope
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	sat->family   = AF_TIPC;
	sat->scope    = scope;
  OUTPUT:
	sv

=head2 void _tipc_fill_id(SV *sv, unsigned int ref, unsigned int node)

Fill in the fields which are specific to ID sockaddrs.  Ref is a 32-bit integer
which is autogenerated by the OS, and unique for every open socket in the
system.  Node is the packed TIPC address.  tipc_addr can create this from the
components, or see _tipc_fill_id_pieces().

=cut

void
_tipc_fill_id(sv, ref, node)
	SV *sv
	unsigned int ref
	unsigned int node
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	sat->addrtype     = TIPC_ADDR_ID;
	sat->addr.id.ref  = ref;
	sat->addr.id.node = node;
  OUTPUT:
	sv

=head2 void _tipc_fill_id_pieces(SV *sv, unsigned int ref, unsigned int zone, unsigned int cluster, unsigned int node)

Fill in the fields which are specific to ID sockaddrs.  Ref is a 32-bit integer
which is autogenerated by the OS, and unique for every open socket in the 
system.  <Zone.Cluster.Node> is the TIPC address portion.  These fields get
packed into one 32-bit int with tipc_addr().  See _tipc_fill_id().

=cut

void
_tipc_fill_id_pieces(sv, ref, zone, cluster, node)
	SV *sv
	unsigned int ref
	unsigned int zone
	unsigned int cluster
	unsigned int node
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	sat->addrtype     = TIPC_ADDR_ID;
	sat->addr.id.ref  = ref;
	sat->addr.id.node = tipc_addr(zone, cluster, node);
  OUTPUT:
	sv

=head2 void _tipc_fill_name(SV *sv, unsigned int type, unsigned int instance, unsigned int domain)

Fill in the fields which are specific to NAME sockaddrs.  {Type,Instance} are
both 32-bit integers, which together specify the "name" of the socket.  Domain
specifies where to start from when searching for a name, for connect() and
sendto().

=cut

void
_tipc_fill_name(sv, type, instance, domain)
	SV *sv
	unsigned int type
	unsigned int instance
	unsigned int domain
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	sat->addrtype                = TIPC_ADDR_NAME;
	sat->addr.name.name.type     = type;
	sat->addr.name.name.instance = instance;
	sat->addr.name.domain        = domain;
  OUTPUT:
	sv

=head2 void _tipc_fill_nameseq(SV *sv, unsigned int type, unsigned int lower, unsigned int upper)

Fill in the fields which are specific to NAMESEQ sockaddrs.  Type is a 32-bit
integer, specifying the first half of a NAME.  Lower and Upper are also 32-bit
integers, which specify a range of Instances, which make up the second half of
the NAME.  They go together like {Type,Lower,Upper}, to specify a range of
names to use in multicast communications.

=cut

void
_tipc_fill_nameseq(sv, type, lower, upper)
	SV *sv
	unsigned int type
	unsigned int lower
	unsigned int upper
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	sat->addrtype           = TIPC_ADDR_NAMESEQ;
	sat->addr.nameseq.type  = type;
	sat->addr.nameseq.lower = lower;
	sat->addr.nameseq.upper = upper;
  OUTPUT:
	sv

=head2 void stringify(SV *sv)

Stringifies the sockaddr, obviously.  This is great for user interface stuff
and logfiles, but note that the string it returns is missing some (possibly
useful) portions of the sockaddr_tipc, Scope and Domain for example.

=cut

SV *
stringify(sv)
	SV *sv
  INIT:
	struct node_addr;
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	/* _tipc_sanity_check already checked AF_INET for us. */
	switch(sat->addrtype) {
	  case 0:
		RETVAL = newSVpvf("(uninitialized addrtype)");
		break;
	  case TIPC_ADDR_ID: /* by TIPC address and ref-id */
		RETVAL = newSVpvf("<%u.%u.%u:%u>",tipc_zone(sat->addr.id.node),
			tipc_cluster(sat->addr.id.node),tipc_node(sat->addr.id.node),
			sat->addr.id.ref);
		break;
	  case TIPC_ADDR_NAME: /* by name (NOTE: "domain" isn't shown) */
		RETVAL = newSVpvf("{%u, %u}",sat->addr.name.name.type,
			sat->addr.name.name.instance);
		break;
	  case TIPC_ADDR_NAMESEQ: /* multicast name range */
		RETVAL = newSVpvf("{%u, %u, %u}",sat->addr.nameseq.type,
			sat->addr.nameseq.lower,sat->addr.nameseq.upper);
		break;
	  default:
		RETVAL = newSVpvf("(invalid addrtype)");
		break;
	}
  OUTPUT:
	RETVAL

=head2 lowlevel field-access routines.

Wrappers for the get/set routines for each field of struct sockaddr_tipc.
sockaddr_tipc.family needs to be readonly, in order for the sanity checks
to pass.  So, we don't provide a set_family function.  Everything else
is read/writable.

I wish XS didn't require so much whitespace.  These should be made quite a bit
more compact.

Start with the get_* functions.

=cut

U16
get_family(sv)
	SV *sv
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	RETVAL = sat->family;
  OUTPUT:
	RETVAL

U8
get_addrtype(sv)
	SV *sv
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	RETVAL = sat->addrtype;
  OUTPUT:
	RETVAL

I8
get_scope(sv)
	SV *sv
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	RETVAL = sat->scope;
  OUTPUT:
	RETVAL

U32
get_ref(sv)
	SV *sv
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	RETVAL = sat->addr.id.ref;
  OUTPUT:
	RETVAL

U32
get_id(sv)
	SV *sv
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	RETVAL = sat->addr.id.node;
  OUTPUT:
	RETVAL

U32
get_zone(sv)
	SV *sv
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	RETVAL = tipc_zone(sat->addr.id.node);
  OUTPUT:
	RETVAL

U32
get_cluster(sv)
	SV *sv
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	RETVAL = tipc_cluster(sat->addr.id.node);
  OUTPUT:
	RETVAL

U32
get_node(sv)
	SV *sv
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	RETVAL = tipc_node(sat->addr.id.node);
  OUTPUT:
	RETVAL

U32
get_ntype(sv)
	SV *sv
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	RETVAL = sat->addr.name.name.type;
  OUTPUT:
	RETVAL

U32
get_instance(sv)
	SV *sv
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	RETVAL = sat->addr.name.name.instance;
  OUTPUT:
	RETVAL

U32
get_domain(sv)
	SV *sv
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	RETVAL = sat->addr.name.domain;
  OUTPUT:
	RETVAL

U32
get_stype(sv)
	SV *sv
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	RETVAL = sat->addr.nameseq.type;
  OUTPUT:
	RETVAL

U32
get_lower(sv)
	SV *sv
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	RETVAL = sat->addr.nameseq.lower;
  OUTPUT:
	RETVAL

U32
get_upper(sv)
	SV *sv
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	RETVAL = sat->addr.nameseq.upper;
  OUTPUT:
	RETVAL

=pod

And here are the set_* functions.  I hate how big and ugly these are...
XS needs a Class::MethodMaker equivalent.

=cut

U8
set_addrtype(sv,arg)
	SV *sv
	U8 arg
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	RETVAL = sat->addrtype = arg;
  OUTPUT:
	RETVAL

I8
set_scope(sv,arg)
	SV *sv
	I8 arg
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	RETVAL = sat->scope = arg;
  OUTPUT:
	RETVAL

U32
set_ref(sv,arg)
	SV *sv
	U8 arg
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	RETVAL = sat->addr.id.ref = arg;
  OUTPUT:
	RETVAL

U32
set_id(sv,arg)
	SV *sv
	U8 arg
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	RETVAL = sat->addr.id.node = arg;
  OUTPUT:
	RETVAL

U32
set_zone(sv,arg)
	SV *sv
	U8 arg
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	sat->addr.id.node = tipc_addr(arg,tipc_cluster(sat->addr.id.node),tipc_node(sat->addr.id.node));
	RETVAL = arg;
  OUTPUT:
	RETVAL

U32
set_cluster(sv,arg)
	SV *sv
	U8 arg
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	sat->addr.id.node = tipc_addr(tipc_zone(sat->addr.id.node),arg,tipc_node(sat->addr.id.node));
	RETVAL = arg;
  OUTPUT:
	RETVAL

U32
set_node(sv,arg)
	SV *sv
	U8 arg
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	sat->addr.id.node = tipc_addr(tipc_zone(sat->addr.id.node),tipc_cluster(sat->addr.id.node),arg);
	RETVAL = arg;
  OUTPUT:
	RETVAL

U32
set_ntype(sv,arg)
	SV *sv
	U8 arg
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	RETVAL = sat->addr.name.name.type = arg;
  OUTPUT:
	RETVAL

U32
set_instance(sv,arg)
	SV *sv
	U8 arg
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	RETVAL = sat->addr.name.name.instance = arg;
  OUTPUT:
	RETVAL

U32
set_domain(sv,arg)
	SV *sv
	U8 arg
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	RETVAL = sat->addr.name.domain = arg;
  OUTPUT:
	RETVAL

U32
set_stype(sv,arg)
	SV *sv
	U8 arg
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	RETVAL = sat->addr.nameseq.type = arg;
  OUTPUT:
	RETVAL

U32
set_lower(sv,arg)
	SV *sv
	U8 arg
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	RETVAL = sat->addr.nameseq.lower = arg;
  OUTPUT:
	RETVAL

U32
set_upper(sv,arg)
	SV *sv
	U8 arg
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	RETVAL = sat->addr.nameseq.upper = arg;
  OUTPUT:
	RETVAL

=pod

get_type()/set_type() wrappers to choose nameseq.type versus name.name.type.
These are only here just in case they change the sockaddr_tipc structure so the
two no longer share the same memory location via a union.  Pretty unlikely...

=cut

U32
get_type(sv)
	SV *sv
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	switch(sat->addrtype) {
		case TIPC_ADDR_NAME:
			RETVAL = sat->addr.name.name.type;
			break;
		case TIPC_ADDR_NAMESEQ:
			RETVAL = sat->addr.nameseq.type;
			break;
		default:
			croak("get_type() called for a typeless sockaddr.");
	}
  OUTPUT:
	RETVAL

U32
set_type(sv,arg)
	SV *sv
	U8 arg
  INIT:
	SAT *sat = _tipc_sanity_check(sv);
  CODE:
	switch(sat->addrtype) {
		case TIPC_ADDR_NAME:
			RETVAL = sat->addr.name.name.type = arg;
			break;
		case TIPC_ADDR_NAMESEQ:
			RETVAL = sat->addr.nameseq.type = arg;
			break;
		default:
			croak("set_type() called for a typeless sockaddr.");
	}
  OUTPUT:
	RETVAL

=pod

Finally, an SV which purposefully leaks scalars, to make sure the memory leak
tester is effective.  Returns true if it leaked a scalar, false otherwise.
Don't ever call this.

=cut

U32
__leak_a_scalar(sv)
	SV *sv
  CODE:
	RETVAL = newSVpvf("leaky leak") ? 1 : 0;
  OUTPUT:
	RETVAL
