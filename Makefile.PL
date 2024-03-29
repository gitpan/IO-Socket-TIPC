use 5.006002;
use ExtUtils::MakeMaker;

# Tell CPANPLUS (and everyone else) right up-front that this module only works
# on selected platforms.

my %supported_platforms = ( # capitalized the way they appear in $^O
    "linux"   => 1,
    "solaris" => 1,
);

# The string "No support for os" is a CPANPLUS hint that it shouldn't send me
# irrelevant test failures for unsupported platforms.

die("No support for os: $^O\n".
    "Yet.  For the moment, TIPC only seems to exist on Linux and Solaris.\n")
     unless exists($supported_platforms{$^O});

# Now we get to try to find tipc.h.
# The Linux kernel's tipc.h likes to include linux/types.h, so somewhere along
# the line, our include path needs to have a linux/types.h in it.  The tipc.h
# from tipc-1.5.10.tar.gz also includes linux/skbuff.h, in addition to
# linux/types.h.  However, this doesn't necessarily have to be the same
# version of linux as the one we pulled tipc.h from, and both types.h and
# skbuff.h are very commonly found in /usr/include/linux/.  And neither tipc.h
# file has any other external dependencies.  And I'd assume the Solaris tipc.h
# doesn't depend on any Linux stuff.  All of this means several important
# things for us:
# 
# * we can find any tipc.h file in either the tipc-addon sources or the linux
#   kernel sources, or even the standard /usr/include fare, and use it without
#   having to care which it is.
# 
# * we can just copy it into the current directory.  This avoids another
#   headerfile nightmare when (for instance) something includes <time.h> and
#   it really gets linux/time.h, which clashes horribly with sys/time.h.  And
#   it doesn't need all the extra staleness-checks a symlink would require.
# 
# * the C file can simply include "tipc.h", and we don't have to generate a
#   custom-prefixed line in an autogenerated headerfile just to include it.
# 
# * When/if tipc.h includes linux/types.h and linux/skbuff.h, it can just use
#   whatever file got installed into /usr/include/linux/ by glibc.  It doesn't
#   matter whether the headers are from a different version of linux, as long
#   as they haven't changed the userspace API.  Which never happens.  Heh.
# 
# * we don't have to specify BOTH -Ilinux/include and -Ilinux/include/linux,
#   or any such nonsense.
# 
# * We don't actually have to search for a kernel at all, if we already know
#   where tipc.h is.
# 
# * If the user can't figure out all this environment variable stuff we're
#   blathering about, (s)he can make the whole problem go away by simply
#   copying the file in for us.
# 
# So, that's my strategy.

unless(-f 'tipc.h') {
	my $uname_r = `uname -r`;
	chomp $uname_r;
	$uname_r = "." unless length $uname_r;
	my @possibilities = (
		"/lib/modules/$uname_r/source/include/linux",
		"/usr/src/linux/include/linux",
		"/usr/include/linux",
		"/opt/SUNWtipc/include/solaris",
	);
	if(exists($ENV{PATH_TO_TIPC})) {
		unshift(@possibilities, $ENV{PATH_TO_TIPC} . "/include/net/tipc");
	}
	if(exists($ENV{KERNDIR})) {
		unshift(@possibilities, $ENV{KERNDIR}."/include/linux");
	}
	if(exists($ENV{PATH_TO_LINUX})) {
		unshift(@possibilities, $ENV{PATH_TO_LINUX} . "/include/linux");
	}
	print("I'm going to try to find a tipc.h header file.\n");
	foreach my $poss (@possibilities) {
		if(defined($poss) && -f "$poss/tipc.h") {
			print("Hey, $poss/tipc.h exists, I'll use it.\n");
			system("cp -f $poss/tipc.h .");
			last;
		} else {
			print("$poss/tipc.h does not exist...\n") if defined $poss;
		}
	}
	
	print("\n");
	# I know the first line of this die() message looks a bit awkward.
	# The string "OS unsupported" is another one of those CPANPLUS hints,
	# telling it not to send me irrelevant test-fail messages for boxes
	# which are missing tipc.h.
	# Hey, it was either this or "No library found for -l<libname>"...
	die "This version of your OS unsupported - get a kernel with TIPC support,\n"
	   ."or download the addon package from tipc.sourceforge.net.\n"
	   ."* If you're using the Linux addon package, try telling me where to find it:\n"
	   ."  PATH_TO_TIPC=/home/user/tipc-1.5.10 perl Makefile.PL\n"
	   ."* Alternately, if you're using CONFIG_TIPC in newer Linux kernels:\n"
	   ."  PATH_TO_LINUX=/usr/src/linux-2.6.16 perl Makefile.PL\n"
	   ."* Solaris users get TIPC support by installing the addon package from\n"
	   ."  http://opensolaris.org/os/project/tipc/ - this will install tipc.h\n"
	   ."  in the right place for you.\n"
	    	unless -f 'tipc.h';
}

WriteMakefile(
    NAME              => 'IO::Socket::TIPC',
    VERSION_FROM      => 'lib/IO/Socket/TIPC.pm', # finds $VERSION
    PREREQ_PM         => {
                         Scalar::Util    => 0,
                         },
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/IO/Socket/TIPC.pm', # retrieve abstract from module
       AUTHOR         => 'Mark Glines <mark-tipc@glines.org>') : ()),
    LIBS              => [''], # e.g., '-lm'
    DEFINE            => '', # e.g., '-DHAVE_SOMETHING
    INC               => '', # e.g., '-I. -I/usr/include/other'
    clean             => { FILES => 'tipc.h' },
);
if  (eval {require ExtUtils::Constant; 1}) {
  # If you edit these definitions to change the constants used by this module,
  # you will need to use the generated const-c.inc and const-xs.inc
  # files to replace their "fallback" counterparts before distributing your
  # changes.  Also update the test spec, and the @EXPORT_OK variables.
  my @names = (qw(AF_TIPC PF_TIPC SOL_TIPC TIPC_ADDR_ID TIPC_ADDR_MCAST
		 TIPC_ADDR_NAME TIPC_ADDR_NAMESEQ TIPC_CFG_SRV
		 TIPC_CLUSTER_SCOPE TIPC_CONN_SHUTDOWN TIPC_CONN_TIMEOUT
		 TIPC_CRITICAL_IMPORTANCE TIPC_DESTNAME TIPC_DEST_DROPPABLE
		 TIPC_ERRINFO TIPC_ERR_NO_NAME TIPC_ERR_NO_NODE
		 TIPC_ERR_NO_PORT TIPC_ERR_OVERLOAD TIPC_HIGH_IMPORTANCE
		 TIPC_IMPORTANCE TIPC_LOW_IMPORTANCE TIPC_MAX_USER_MSG_SIZE
		 TIPC_MEDIUM_IMPORTANCE TIPC_NODE_SCOPE TIPC_OK TIPC_PUBLISHED
		 TIPC_RESERVED_TYPES TIPC_RETDATA TIPC_SRC_DROPPABLE
		 TIPC_SUBSCR_TIMEOUT TIPC_SUB_NO_BIND_EVTS
		 TIPC_SUB_NO_UNBIND_EVTS TIPC_SUB_PORTS TIPC_SUB_SERVICE
		 TIPC_SUB_SINGLE_EVT TIPC_TOP_SRV TIPC_WAIT_FOREVER
		 TIPC_WITHDRAWN TIPC_ZONE_SCOPE));
  ExtUtils::Constant::WriteConstants(
                                     NAME         => 'IO::Socket::TIPC',
                                     NAMES        => \@names,
                                     DEFAULT_TYPE => 'IV',
                                     C_FILE       => 'const-c.inc',
                                     XS_FILE      => 'const-xs.inc',
                                  );

}
else {
  use File::Copy;
  use File::Spec;
  foreach my $file ('const-c.inc', 'const-xs.inc') {
    my $fallback = File::Spec->catfile('fallback', $file);
    copy ($fallback, $file) or die "Can't copy $fallback to $file: $!";
  }
}
