use warnings;
use strict;

package Murakumo_Node::CLI::VPS::Disk::Copy;
use Carp;
use IPC::Cmd qw( run );
use Data::Dumper;
use File::stat;
use Class::Accessor::Lite ( rw => [ qw( src dst ) ] );

use FindBin;
use lib qq{$FindBin::Bin/../lib};
use Murakumo_Node::CLI::Utils;

our $utils   = Murakumo_Node::CLI::Utils->new;
our $config  = $utils->config;

sub new {
  my ($class, $params) = @_;

  my $obj = bless +{}, $class;

  {
    no strict 'refs';
    for my $k ( qw( src dst ) ) {
      $params->{$k}
        or croak "*** src and dst path are required";
    }
  }

  $obj->src( $params->{src} );
  $obj->dst( $params->{dst} );

  return $obj;

}

sub find_stock_image_and_copy {
  my $self = shift;

  if ($config->{stock_image_ext}) {

    my $file_path = sprintf "%s.%s*", $self->src, $config->{stock_image_ext};

    my $org_s = stat $self->src;

    my @files = glob $file_path;
    for my $file ( @files ) {
      my $s = stat $file;

      if ($org_s->mtime > $s->mtime) {
        remove_set( $file );
        next;
      }

      rename $file, $self->dst
        or croak "*** rename error";

      return 1;

    }
  }

  my $copy_command = sprintf "/bin/cp --sparse=auto %s %s", $self->src, $self->dst;
  logging $copy_command;
  my @copied = run ( command => $copy_command );
  if (! $copied[0]) {
    logging $copied[2];
    croak "*** copy error";
  }

  return 1;

}

1;
