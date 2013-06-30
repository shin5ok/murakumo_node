use strict;
use warnings;
use Test::More;

require_ok("Murakumo_Node::CLI::VPS::Disk");

my $obj = Murakumo_Node::CLI::VPS::Disk->new;

{
  no warnings;
  ok(-x $Murakumo_Node::CLI::VPS::Disk::qemu_img_cmd, qq{qemu-img command check});
}

my @methods = qw(
  create
  remove
  path_make
  clone
  maked_file
  make_image_cloning
);
can_ok($obj, @methods);

done_testing();

