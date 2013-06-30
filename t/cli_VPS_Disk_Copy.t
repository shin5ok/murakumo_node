use strict;
use warnings;
use Test::More;

require_ok("Murakumo_Node::CLI::VPS::Disk::Copy");

my $obj = Murakumo_Node::CLI::VPS::Disk::Copy
            ->new({
                    src => q{/dev/random},
                    dst => q{/dev/null},
                  });

my @methods = qw(
  src
  dst
  find_stock_image_and_copy
);

can_ok($obj, @methods);

done_testing();


