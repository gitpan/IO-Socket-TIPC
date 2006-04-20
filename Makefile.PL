use 5.008008;
use ExtUtils::MakeMaker;

# FIXME: Blatant linuxism (for now).  Tell CPANPLUS (and everyone else) right
# up-front that this module only works on Linux.
die("No support for os: $^O\n".
    "Yet.  For the moment, TIPC only seems to exist on Linux.\n")
     unless $^O eq "linux";
my $incdir = '.';
unless(-f "/usr/include/linux/tipc.h") {
	my $uname_r = `uname -r`;
	chomp $uname_r;
	$uname_r = "." unless length $uname_r;
	my @possibilities = (
		"/lib/modules/$uname_r/source/include",
		"/usr/src/linux/include",
		$ENV{KERNDIR},
		# insert other likely places to find a kernel here.
	);
	foreach my $poss (@possibilities) {
		if(defined($poss) && -f "$poss/linux/tipc.h") {
			$incdir = $poss;
			last;
		}
		print("Cannot locate linux/tipc.h!  Building this will fail.\n");
	}
}

WriteMakefile(
    NAME              => 'IO::Socket::TIPC',
    VERSION_FROM      => 'lib/IO/Socket/TIPC.pm', # finds $VERSION
    PREREQ_PM         => {
                         Scalar::Util    => 0,
                         Switch          => 0,
                         Test::Exception => 0,
                         },
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/IO/Socket/TIPC.pm', # retrieve abstract from module
       AUTHOR         => 'Mark Glines <mark-tipc@glines.org>') : ()),
    LIBS              => [''], # e.g., '-lm'
    DEFINE            => '', # e.g., '-DHAVE_SOMETHING
    INC               => "-I$incdir", # e.g., '-I. -I/usr/include/other'
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
