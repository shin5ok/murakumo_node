#!/usr/bin/perl
use strict;
use warnings;
use File::Find;
use Getopt::Long;

my $test;
my $mday;
GetOptions(
            "test"   => \$test,
            "mday=i" => \$mday,
          );
# デフォルト 7 day
$mday ||= 7;

my @dirs = @ARGV;

for my $dir ( @dirs ) {
  find(\&cleanup, $dir);
}

sub cleanup {
  my $file = $File::Find::name;
  if (-f $file and $file =~ /\.unlinked$/) {
    if (-M $file > $mday) {
      if ($test) {
        print "try $file is removed\n"; 
      } else {
        unlink $file;
      }
    }
  }

  return;

}
