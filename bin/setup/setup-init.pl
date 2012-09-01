#!/usr/bin/murakumo-perl
use strict;
use warnings;
use FindBin;

my @inits = glob "$FindBin::Bin/*.init";
warn "murakumo_node init script setup...";
sleep 2;

chdir "/etc/init.d/";
print "chdir /etc/init.d/\n";

for my $init ( @inits ) {
  my ($dst) = $init =~ m{ / ( [^ / ] + ) \. init $ }x or next;
  $dst = lc $dst;
  if (-e $dst) {
    warn "*** $dst is already exist";
    next;
  }
  print "symlink $init to $dst\n";
  symlink $init, $dst;
  system "/sbin/chkconfig $dst on";
}

