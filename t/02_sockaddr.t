use strict;
use warnings;
use IO::Socket::TIPC ':all';
use Test::More;
BEGIN { use_ok('Test::Exception'); }
my $tests;
BEGIN { $tests = 0 };

my $test_exception_loaded = defined($Test::Exception::VERSION);

## NAME
# basic
my $sockaddr = IO::Socket::TIPC::Sockaddr->new('{1,3}');
ok($sockaddr,                                  'simple name returned a value');
is(ref($sockaddr),'IO::Socket::TIPC::Sockaddr','blessed into the right class');
is($sockaddr->stringify(),   '{1, 3}',         'stringify gives me back the same name');

# spaces don't matter in string names
$sockaddr = IO::Socket::TIPC::Sockaddr->new('{1, 3}');
ok($sockaddr,                                  'new() handles strings with spaces');
is($sockaddr->stringify(),   '{1, 3}',         'parse names which contain spaces');

# specify by pieces
$sockaddr = IO::Socket::TIPC::Sockaddr->new(AddrType => 'name', Type => 4242, Instance => 100);
ok($sockaddr,                                  'pieces were accepted');
is($sockaddr->stringify(),   '{4242, 100}',    'pieces parsed correctly');
is($sockaddr->get_type(),    4242,             'type is 4242');
is($sockaddr->get_instance(),100,              'instance is 100');

# omit the AddrType
$sockaddr = IO::Socket::TIPC::Sockaddr->new(Type => 4242, Instance => 100);
ok($sockaddr,                                  'pieces were accepted without AddrType');
is($sockaddr->stringify(),   '{4242, 100}',    'parsed AddrType=name correctly');
is($sockaddr->get_addrtype(),TIPC_ADDR_NAME,   'guessed AddrType=name correctly');

# also pass in a Scope and an integer literal Domain
$sockaddr = IO::Socket::TIPC::Sockaddr->new(AddrType => 'name', Type => 42420, Instance => 10, Scope => 3, Domain => 0x01001001);
ok($sockaddr,                                  'pieces were accepted');
is($sockaddr->stringify(),   '{42420, 10}',    'pieces parsed correctly');
is($sockaddr->get_domain(),  0x01001001,       'domain is set properly');
is($sockaddr->get_scope(),   3,                'scope is set properly');

# try a dotted-tri string Domain
$sockaddr = IO::Socket::TIPC::Sockaddr->new(AddrType => 'name', Type => 42420, Instance => 10, Domain => '<1.2.3>');
ok($sockaddr,                                  'pieces were accepted');
is($sockaddr->stringify(),   '{42420, 10}',    'pieces parsed correctly');
is($sockaddr->get_domain(),  0x01002003,       'domain is set properly');

# try a decimal string Domain
$sockaddr = IO::Socket::TIPC::Sockaddr->new(AddrType => 'name', Type => 42420, Instance => 10, Domain => '16785411');
ok($sockaddr,                                  'pieces were accepted');
is($sockaddr->stringify(),   '{42420, 10}',    'pieces parsed correctly');
is($sockaddr->get_domain(),  0x01002003,       'domain is set properly');

# try a hex string Domain
$sockaddr = IO::Socket::TIPC::Sockaddr->new(AddrType => 'name', Type => 42420, Instance => 10, Domain => '0x01002003');
ok($sockaddr,                                  'pieces were accepted');
is($sockaddr->stringify(),   '{42420, 10}',    'pieces parsed correctly');
is($sockaddr->get_domain(),  0x01002003,       'domain is set properly');

# try the string Scopes
$sockaddr = IO::Socket::TIPC::Sockaddr->new(AddrType => 'name', Type => 42420, Instance => 10, Scope => 'zone');
ok($sockaddr,                                  'pieces were accepted');
is($sockaddr->stringify(),   '{42420, 10}',    'pieces parsed correctly');
is($sockaddr->get_scope(),   TIPC_ZONE_SCOPE,  'scope is set properly');
$sockaddr = IO::Socket::TIPC::Sockaddr->new(AddrType => 'name', Type => 42420, Instance => 10, Scope => 'cluster');
ok($sockaddr,                                  'pieces were accepted');
is($sockaddr->stringify(),   '{42420, 10}',    'pieces parsed correctly');
is($sockaddr->get_scope(),   TIPC_CLUSTER_SCOPE,'scope is set properly');
$sockaddr = IO::Socket::TIPC::Sockaddr->new(AddrType => 'name', Type => 42420, Instance => 10, Scope => 'node');
ok($sockaddr,                                  'pieces were accepted');
is($sockaddr->stringify(),   '{42420, 10}',    'pieces parsed correctly');
is($sockaddr->get_scope(),   TIPC_NODE_SCOPE,  'scope is set properly');

SKIP: {
	skip 'need Test::Exception', 4 unless $test_exception_loaded;
	# catch forgetting to pass Type arg
	throws_ok( sub {
		$sockaddr = IO::Socket::TIPC::Sockaddr->new(AddrType => 'name',Instance => 100)
		}, qr/requires a Type value/,          'catches a forgotten Type argument');
	
	# catch the wrong AddrType
	throws_ok( sub {
		$sockaddr = IO::Socket::TIPC::Sockaddr->new(AddrType => 'id', Type => 4242, Instance => 100)
		}, qr/not valid for AddrType id/,      'catches an incorrect AddrType');
	
	# catch mistakenly passing in Upper arg
	throws_ok( sub {
		$sockaddr = IO::Socket::TIPC::Sockaddr->new(AddrType => 'name', Type => 4242, Instance => 100, Upper => 1000)
		}, qr/Upper not valid for AddrType name/,'catches a mistaken Upper argument');
	
	# catch mistakenly passing in Nonexistent arg
	throws_ok( sub {
		$sockaddr = IO::Socket::TIPC::Sockaddr->new(AddrType => 'name', Type => 4242, Instance => 100, Nonexistent => 1000)
		}, qr/unknown argument Nonexistent/,   'catches an erroneous Nonexistent argument');
}
BEGIN { $tests += 38 };

## NAMESEQ
# string
$sockaddr = IO::Socket::TIPC::Sockaddr->new('{1,3,3}');
ok($sockaddr,                                  'simple nameseq returned a value');
is(ref($sockaddr),'IO::Socket::TIPC::Sockaddr','blessed into the right class');
is($sockaddr->stringify(),   '{1, 3, 3}',      'stringify gives me back the same nameseq');

# spaces don't matter in string names
$sockaddr = IO::Socket::TIPC::Sockaddr->new('{1, 3, 3}');
ok($sockaddr,                                  'returned a value even with a space in it');
is($sockaddr->stringify(),   '{1, 3, 3}',      'nameseq parsed right with a space in it');

# specify by pieces
$sockaddr = IO::Socket::TIPC::Sockaddr->new(AddrType => 'nameseq', Type => 4242, Lower => 99, Upper => 100);
ok($sockaddr,                                  'pieces were accepted');
is($sockaddr->stringify(),   '{4242, 99, 100}','pieces parsed correctly');
is($sockaddr->get_type(),    4242,             'type is 4242');
is($sockaddr->get_lower(),   99,               'lower is 99');
is($sockaddr->get_upper(),   100,              'upper is 100');

# omit the AddrType
$sockaddr = IO::Socket::TIPC::Sockaddr->new(Type => 4242, Lower => 99, Upper => 100);
ok($sockaddr,                                  'pieces were accepted without AddrType');
is($sockaddr->stringify(),   '{4242, 99, 100}','parsed AddrType=nameseq correctly');
is($sockaddr->get_addrtype(),TIPC_ADDR_NAMESEQ,'guessed AddrType=nameseq correctly');

# omit the AddrType and Upper
$sockaddr = IO::Socket::TIPC::Sockaddr->new(Type => 4242, Lower => 99);
ok($sockaddr,                                  'pieces were accepted without AddrType, and without Upper');
is($sockaddr->stringify(),   '{4242, 99, 99}', 'parsed AddrType=nameseq correctly, Upper=Lower');
is($sockaddr->get_addrtype(),TIPC_ADDR_NAMESEQ,'guessed AddrType=nameseq correctly');

# also pass in a Scope
$sockaddr = IO::Socket::TIPC::Sockaddr->new(AddrType => 'nameseq', Type => 424, Lower => 101, Upper => 102, Scope => 3);
ok($sockaddr,                                  'pieces were accepted');
is($sockaddr->stringify(),   '{424, 101, 102}','pieces parsed correctly');
is($sockaddr->get_scope(),   3,                'scope is set properly');

SKIP: {
	skip 'need Test::Exception', 4 unless $test_exception_loaded;
	# catch forgetting to pass Type arg
	throws_ok( sub {
		$sockaddr = IO::Socket::TIPC::Sockaddr->new(AddrType => 'nameseq',Lower => 100)
		}, qr/requires a Type value/,          'catches a forgotten Type argument');
	
	# catch the wrong AddrType
	throws_ok( sub {
		$sockaddr = IO::Socket::TIPC::Sockaddr->new(AddrType => 'name', Type => 4242, Lower => 100)
		}, qr/not valid for AddrType name/,    'catches an incorrect AddrType');
	
	# catch mistakenly passing in Ref arg
	throws_ok( sub {
		$sockaddr = IO::Socket::TIPC::Sockaddr->new(AddrType => 'nameseq', Type => 4242, Lower => 100, Ref => 1000)
		}, qr/Ref not valid for AddrType nameseq/, 'catches a mistaken Ref argument');
	
	# catch mistakenly passing in Nonexistent arg
	throws_ok( sub {
		$sockaddr = IO::Socket::TIPC::Sockaddr->new(AddrType => 'nameseq', Type => 4242, Lower => 100, Nonexistent => 1000)
		}, qr/unknown argument Nonexistent/,   'catches an erroneous Nonexistent argument');
}
BEGIN { $tests += 23 };


## ID
# string
$sockaddr = IO::Socket::TIPC::Sockaddr->new('<1.2.3:4>');
ok($sockaddr,                                  'simple id returned a value');
is(ref($sockaddr),'IO::Socket::TIPC::Sockaddr','blessed into the right class');
is($sockaddr->stringify(),   '<1.2.3:4>',      'stringify gives me back the same id');

# specify by pieces
$sockaddr = IO::Socket::TIPC::Sockaddr->new(AddrType => 'id', Zone => 1, Cluster => 2, Node => 3, Ref => 4);
ok($sockaddr,                                  'pieces were accepted');
is($sockaddr->stringify(),   '<1.2.3:4>',      'pieces parsed correctly');
is($sockaddr->get_zone(),    1,                'zone is 1');
is($sockaddr->get_cluster(), 2,                'cluster is 2');
is($sockaddr->get_node(),    3,                'node is 3');
is($sockaddr->get_ref(),     4,                'ref is 4');

# specify node-address as a string
$sockaddr = IO::Socket::TIPC::Sockaddr->new(AddrType => 'id', Id => '<1.2.3>', Ref => 4);
ok($sockaddr,                                  'pieces were accepted');
is($sockaddr->stringify(),   '<1.2.3:4>',      'pieces parsed correctly');
is($sockaddr->get_zone(),    1,                'zone is 1');
is($sockaddr->get_cluster(), 2,                'cluster is 2');
is($sockaddr->get_node(),    3,                'node is 3');
is($sockaddr->get_ref(),     4,                'ref is 4');

# specify the whole thing as a string
$sockaddr = IO::Socket::TIPC::Sockaddr->new(AddrType => 'id', Id => '<1.2.3:4>');
ok($sockaddr,                                  'pieces were accepted');
is($sockaddr->stringify(),   '<1.2.3:4>',      'pieces parsed correctly');
is($sockaddr->get_zone(),    1,                'zone is 1');
is($sockaddr->get_cluster(), 2,                'cluster is 2');
is($sockaddr->get_node(),    3,                'node is 3');
is($sockaddr->get_ref(),     4,                'ref is 4');

# omit the AddrType
$sockaddr = IO::Socket::TIPC::Sockaddr->new(Id => '<1.2.3:4>');
ok($sockaddr,                                  'pieces were accepted without AddrType');
is($sockaddr->stringify(),   '<1.2.3:4>',      'parsed AddrType=id correctly');
is($sockaddr->get_addrtype(),TIPC_ADDR_ID,     'guessed AddrType=id correctly');

# omit the AddrType and Ref
$sockaddr = IO::Socket::TIPC::Sockaddr->new(Id => '<1.2.3>');
ok($sockaddr,                                  'pieces were accepted without AddrType');
is($sockaddr->stringify(),   '<1.2.3:0>',      'Reference is 0 by default');
is($sockaddr->get_addrtype(),TIPC_ADDR_ID,     'guessed AddrType=id correctly');

SKIP: {
	skip 'need Test::Exception', 4 unless $test_exception_loaded;
	# catch forgetting to pass Node arg
	throws_ok( sub {
		$sockaddr = IO::Socket::TIPC::Sockaddr->new(AddrType => 'id', Zone => 1, Cluster => 2, Ref => 4);
		}, qr/requires a Node value/,          'catches a forgotten Node argument');
	
	# catch the wrong AddrType
	throws_ok( sub {
		$sockaddr = IO::Socket::TIPC::Sockaddr->new(AddrType => 'name', Zone => 1, Cluster => 2, Node => 3, Ref => 4);
		}, qr/not valid for AddrType name/,    'catches an incorrect AddrType');
	
	# catch mistakenly passing in Upper arg
	throws_ok( sub {
		$sockaddr = IO::Socket::TIPC::Sockaddr->new(AddrType => 'id', Zone => 1, Cluster => 2, Node => 3, Ref => 4, Upper => 1000);
		}, qr/Upper not valid for AddrType id/,'catches a mistaken Upper argument');
	
	# catch mistakenly passing in Nonexistent arg
	throws_ok( sub {
		$sockaddr = IO::Socket::TIPC::Sockaddr->new(AddrType => 'id', Zone => 1, Cluster => 2, Node => 3, Ref => 4, Nonexistent => 1000);
		}, qr/unknown argument Nonexistent/,   'catches an erroneous Nonexistent argument');
}
BEGIN { $tests += 31 };



BEGIN { plan tests => $tests };
