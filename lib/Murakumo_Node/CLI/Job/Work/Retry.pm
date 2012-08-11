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
  my $retry = 100;

  my $ok  = 0;
  my $log = "";
  JOB:
  while (--$retry) {
    my $r;
    local $@;
    eval {
      $r = $func->( $func_args );
    };
    warn "---------------------";
    warn $@;
    warn "---------------------";
    if (! $r or $@ ) {
      warn "job failed(retry left: $retry)";
      $log .= "job failed(retry left: $retry)\n";
      sleep 1;
    } else {
      $ok = 1;
      last JOB;
    }
  }
  if (! $ok) {
    my $log = "job failed";
    return $job->failed($log);
  }

  $job->completed;

}

1;
