use strict;
use warnings;
package Murakumo_Node::CLI::Job::Work::VPS::Clone;
use Carp;

use lib qw(/home/smc/Murakumo_Node/lib);
use Murakumo_Node::CLI::VPS::Disk;

# boot部分を作る
sub work {
  my ($self, $job) = @_;

  my $arg = $job->arg;
use Data::Dumper;
warn Dumper $arg;
  no strict 'refs';

  my %param = %$arg;

  my $r;
  local $@;
  eval {
    my $obj = Murakumo_Node::CLI::VPS::Disk->new;
    $r = $obj->clone( \%param );
  };
  if (! $r or $@ ) {
    my $log = sprintf "clone failed %s", Dumper $arg;
    $@ and $log .= "($@)";
    $log =~ s/\n/ /g;
    return $job->failed($log);
  }

  $job->completed;
}


1;
