#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <linux/tipc.h>

#include "const-c.inc"

MODULE = IO::Socket::TIPC		PACKAGE = IO::Socket::TIPC

INCLUDE: const-xs.inc

MODULE = IO::Socket::TIPC		PACKAGE = IO::Socket::TIPC::Sockaddr

PROTOTYPES: ENABLE

# What follows are some accessor functions for the sockaddr_tipc structure.
# I could have simply done some pack()/unpack() statements in Perl code, but
# that would break horribly if they ever changed the structure, resulting in
# size mismatches and such.  This way it'll stay valid as long as they leave
# a migration path.

# Also note that these routines will break horribly if you call them with a
# wrongly sized (clobbered, truncated, whatever) SV.  Calling code should be
# careful to create the SV with _create(), and never write to it directly.
# For this reason, these functions aren't published, and are only called from
# TIPC/Sockaddr.pm.

SV *
_create()
  INIT:
	struct sockaddr_tipc sat;
  CODE:
	memset(&sat,0,sizeof(sat));
	RETVAL = newSVpvn((void*)&sat,sizeof(sat));
#	SvUTF8_off(RETVAL);
  OUTPUT:
	RETVAL

void
_clear_tipc(sv)
	SV *sv
  CODE:
	memset((void*)SvPV_nolen(sv),0,sizeof(struct sockaddr_tipc));
  OUTPUT:
	sv

void
_fill_tipc_common(sv, scope)
	SV *sv
	unsigned char scope
  CODE:
	struct sockaddr_tipc *sat = (struct sockaddr_tipc *)SvPV_nolen(sv);
	sat->family   = AF_TIPC;
	sat->scope    = scope;
  OUTPUT:
	sv

void
_fill_tipc_id(sv, ref, node)
	SV *sv
	unsigned int ref
	unsigned int node
  CODE:
	struct sockaddr_tipc *sat = (struct sockaddr_tipc *)SvPV_nolen(sv);
	sat->addrtype     = TIPC_ADDR_ID;
	sat->addr.id.ref  = ref;
	sat->addr.id.node = node;
  OUTPUT:
	sv

void
_fill_tipc_id_pieces(sv, ref, zone, cluster, node)
	SV *sv
	unsigned int ref
	unsigned int zone
	unsigned int cluster
	unsigned int node
  CODE:
	struct sockaddr_tipc *sat = (struct sockaddr_tipc *)SvPV_nolen(sv);
	sat->addrtype     = TIPC_ADDR_ID;
	sat->addr.id.ref  = ref;
	sat->addr.id.node = tipc_addr(zone, cluster, node);
  OUTPUT:
	sv

void
_fill_tipc_name(sv, type, instance, domain)
	SV *sv
	unsigned int type
	unsigned int instance
	unsigned int domain
  CODE:
	struct sockaddr_tipc *sat    = (struct sockaddr_tipc *)SvPV_nolen(sv);
	sat->addrtype                = TIPC_ADDR_NAME;
	sat->addr.name.name.type     = type;
	sat->addr.name.name.instance = instance;
	sat->addr.name.domain        = domain;
  OUTPUT:
	sv

void
_fill_tipc_nameseq(sv, type, upper, lower)
	SV *sv
	unsigned int type
	unsigned int upper
	unsigned int lower
  CODE:
	struct sockaddr_tipc *sat = (struct sockaddr_tipc *)SvPV_nolen(sv);
	sat->addrtype           = TIPC_ADDR_NAMESEQ;
	sat->addr.nameseq.type  = type;
	sat->addr.nameseq.lower = lower;
	sat->addr.nameseq.upper = upper;
  OUTPUT:
	sv

SV *
_stringify(sv)
	SV *sv
  CODE:
	struct sockaddr_tipc *sat = (struct sockaddr_tipc *)SvPV_nolen(sv);
	if(sat->family != AF_TIPC) {
		RETVAL = newSVpvf("(invalid family)");
	} else {
		struct node_addr;
		switch(sat->addrtype) {
		  case 0:
			RETVAL = newSVpvf("(uninitialized addrtype)");
			break;
		  case TIPC_ADDR_ID: /* by TIPC address and ref-id */
			RETVAL = newSVpvf("<%i.%i.%i:%i>",tipc_zone(sat->addr.id.node),
				tipc_cluster(sat->addr.id.node),tipc_node(sat->addr.id.node),
				sat->addr.id.ref);
			break;
		  case TIPC_ADDR_NAME: /* by port (NOTE: "domain" isn't shown) */
			RETVAL = newSVpvf("{%i, %i}",sat->addr.name.name.type,
				sat->addr.name.name.instance);
			break;
		  case TIPC_ADDR_NAMESEQ: /* multicast port range */
			RETVAL = newSVpvf("{%i, %i, %i}",sat->addr.nameseq.type,
				sat->addr.nameseq.lower,sat->addr.nameseq.upper);
			break;
		  default:
			RETVAL = newSVpvf("(invalid addrtype)");
			break;
		}
	}
  OUTPUT:
	RETVAL
