use strict;
use warnings;
package Murakumo_Node::CLI::Job::Work::VPS::Shutdown;
use Carp;

use FindBin;
use lib qq{$FindBin::Bin/../lib};
use Murakumo_Node::CLI::VPS;

my $method = 'shutdown';

sub work {
  my ($self, $job) = @_;

  my ($id, $uuid);
  {
    no strict 'refs';
    $id   = $job->arg->{id}   || "";
    $uuid = $job->arg->{uuid} || ""; # 優先
  }

  if (! $id and ! $uuid) {
    return $job->failed("*** id and uuid both empty !!!");
  }

  my %ids = ( uuid => $uuid, id => $id ); 
  my $r;
  local $@;
  eval {
    my $vps_obj = Murakumo_Node::CLI::VPS->new( \%ids ); 
    $r = $vps_obj->$method;
  };
  if (! $r or $@ ) {
    my $log = "uuid: $uuid, $id: $id => $method failed";
    $log .= "($@)";
    $log =~ s/\n/ /g;
    return $job->failed($log);
  }

  $job->completed;

}

1;
