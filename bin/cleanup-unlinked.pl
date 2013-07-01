#!/usr/bin/env murakumo-perl
use strict;
use warnings;
use File::Find;
use Carp;
use opts;

use FindBin;
use lib qq{$FindBin::Bin/../lib};
use Murakumo_Node::CLI::Utils;

my $config = Murakumo_Node::CLI::Utils->config;

opts my $test => { isa => 'Bool' },
     my $mday => { isa => 'Int', default => 7 };
my @dirs = @ARGV;

if (@dirs == 0) {
  croak "*** no dir args";
}

for my $dir ( @dirs ) {
  $dir =~ m{^\s*/\s+}     and next;
  $dir =~ m{^/[0-9a-z]+}i or  next;
  find(\&cleanup, $dir);
}

sub cleanup {
  my $file = $File::Find::name;
  my $ext  = exists $config->{unlink_disk_ext}
           ? $config->{unlink_disk_ext}
           : q{unlinked};

  if ($ext =~ /^\s*$/) {
    croak "*** critical error...cleanup ext is empty";
  }
  if ($ext !~ /[a-z0-9\-\_]{2}/i) {
    croak "*** critical error...cleanup ext is invalid";
  }

  if (-f $file and $file =~ /\.img\.${ext}$/) {
    if (-M $file > $mday) {
      my $log = "try $file is removed";
      if ($test) {
        print $log, "\n";
      } else {
        logging $log;
        unlink $file;
      }
    }
  }

  return;

}

