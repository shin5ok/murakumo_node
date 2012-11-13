use warnings;
use strict;

package Murakumo_Node::CLI::Libvirt::Storage 0.03;
use FindBin;
use Carp;
use Data::Dumper;
use File::Path;
use XML::TreePP ();
use JSON;
use IPC::Cmd qw(run_forked);

use lib qq{$FindBin::Bin/../lib};
use Murakumo_Node::CLI::Utils;
use Murakumo_Node::CLI::Libvirt;
use base q(Murakumo_Node::CLI::Libvirt);

use Murakumo_Node::CLI::Libvirt::XML;
use Murakumo_Node::CLI::Remote_JSON_API;

my $config = Murakumo_Node::CLI::Utils->config;

sub del {
  my ($self, $uuid) = @_;

  $self->is_mounted_storage( $uuid )
    or return 1;

  my $api_response = Murakumo_Node::CLI::Remote_JSON_API->new->get("/storage/info/", { uuid => $uuid });
  my $api_result   = decode_json $api_response->content;

  if (! $self->umount_nfs_storage( $api_result->{data} )) {
    croak "*** umount error";
  } else {
    return 1;
  }

}

sub is_mounted_storage {
  my ($self, $uuid) = @_;
  my $mount   = `/bin/mount`;
  open my $mounts, "<", "/proc/mounts";
  my $mounted = 0;
  while (my $line = <$mounts>) {
    if ($line =~ m{/$uuid/?}) {
      $mounted = 1;
      last;
    }
  }
  close $mounts;

  return $mounted;

}


sub add_by_path {
  my ($self, $storage_path) = @_;
  warn "storage_path : $storage_path";

  # 先頭から、最初のuuidっぽい文字列を取得
  my ($storage_uuid) = $storage_path =~ m{ / (
                                             [0-9a-z]{8} \-
                                             [0-9a-z]{4} \-
                                             [0-9a-z]{4} \-
                                             [0-9a-z]{4} \-
                                             [0-9a-z]{12}
                                           ) / }xoms;

  if (! $storage_uuid ) {
    logger "*** like uuid get from $storage_path is failure";
    return 0;
  }

  return $self->add( $storage_uuid );

}


sub add {
  my ($self, $uuid) = @_;

  if ($self->is_mounted_storage( $uuid ) ) {
    # 既に mount されていたら
    return 1;

  }

  my $api_response = Murakumo_Node::CLI::Remote_JSON_API->new->get("/storage/info/", { uuid => $uuid });
  my $api_result   = decode_json $api_response->content;
  if (exists $api_result->{result} and $api_result->{result} == 1) {
    no strict 'refs';

    my $data = $api_result->{data};

    # ディレクトリを作成
    -e $data->{mount_path} or mkpath $data->{mount_path}, { verbose => 1 };

    $self->mount_nfs_storage( $data );
    return 1;

  } else {
    croak "*** storage info $uuid get error...";
  }

}

sub mount_nfs_storage {
  my $self   = shift;
  my $data   = shift;
  my $umount = shift || 0;

  # {
  # 
  #     "authed": 1,
  #     "data": {
  #         "mount_path": "/nfs/384b1103-b4d6-42a8-9f3e-533be1955447",
  #         "type": "nfs",
  #         "export_path": "/export/vps",
  #         "uuid": "384b1103-b4d6-42a8-9f3e-533be1955447",
  #         "available": "1",
  #         "host": "192.168.233.123"
  #     },
  #     "uuid": "384b1103-b4d6-42a8-9f3e-533be1955447",
  #     "project_id": "00000010",
  #     "message": "",
  #     "result": 1
  # 
  # }

  my $command;

  if (not $umount) {
    my $option  = $config->{nfs_mount_option}
                ? "-o $config->{nfs_mount_option}"
                : "";

    $command = sprintf "/bin/mount %s %s:%s %s",
                          $option,
                          $data->{host},
                          $data->{export_path},
                          $data->{mount_path};
  } else {
    # 強制umount -l は しない
    $command = sprintf "/bin/umount %s", $data->{mount_path};

  }
                           
  warn "command: $command";
  my $result_ref = run_forked( $command, { timeout => 10 } ); 

 $result_ref->{exit_code} == 0
   or croak "*** nfs mount error($command)";

 return 1;

}

sub umount_nfs_storage {
  my ($self, $data) = @_;
  $self->mount_nfs_storage( $data, 1 );

}


1;
