use strict;
use warnings;
package Murakumo_Node::CLI::Job::Work::Retry;
use Carp;

use FindBin;
use lib qq{$FindBin::Bin/../lib};

sub work {
  my ($self, $job) = @_;

  my $func      = $job->arg->{func};
  my $func_args = $job->arg->{func_args};

  my $r;
  local $@;
  eval {
    $r = $func->( $func_args );
  };
  if (! $r or $@ ) {
    my $log = "job failed";
    return $job->failed($log);
  }

  $job->completed;

}

1;
