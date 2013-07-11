use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Murakumo_Node';
use Murakumo_Node::Controller::VPS;

SKIP: {
  subtest "api /vps/boot" => sub {
    ok 1;
  };
}

SKIP: {
  subtest "api /vps/boot_from_json" => sub {
    ok 1;
  };
}

SKIP: {
  subtest "api /vps/shutdown" => sub {
    ok 1;
  };
}

SKIP: {
  subtest "api /vps/terminate" => sub {
    ok 1;
  };
}

SKIP: {
  subtest "api /vps/cdrom" => sub {
    ok 1;
  };
}

SKIP: {
  subtest "api /vps/create" => sub {
    ok 1;
  };
}

SKIP: {
  subtest "api /vps/clone" => sub {
    ok 1;
  };
}

done_testing();
