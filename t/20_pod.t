use strict;
use warnings;
use Test::More;
eval "use Test::Pod 1.00";
plan skip_all => "need Test::Pod" if $@;
all_pod_files_ok();
