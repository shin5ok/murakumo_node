use warnings;
use strict;

package Murakumo_Node::CLI::VPS::Disk;
use Path::Class;
use Carp;
use IPC::Open3;
use File::Basename;
use File::Path qw(mkpath);
use Data::Dumper;
use IPC::Cmd qw(run);

use JSON;
use LWP::UserAgent;
use HTTP::Request::Common qw( POST GET );
use XML::TreePP;
use DateTime;

use FindBin;
use lib qq{$FindBin::Bin/../lib};
use Murakumo_Node::CLI::Guestfs;
use Murakumo_Node::CLI::Utils;
use Murakumo_Node::CLI::Libvirt;
use base qw(Murakumo_Node::CLI::Libvirt);
require Murakumo_Node::CLI::Job::Callback;

our $utils   = Murakumo_Node::CLI::Utils->new;
our $config  = $utils->config;
our $vm_root = $config->{vm_root};

our $qemu_img_cmd = "/usr/bin/qemu-img";

sub create {
  my ($self, $params) = @_;
  dumper($params);

  my $disk_param_ref = $params->{disks};
  my $reserve_uuid   = $params->{reserve_uuid};
  my $vps_uuid       = $params->{vps_uuid};

  require Murakumo_Node::CLI::Libvirt::Storage;
  my $libvirt_storage = Murakumo_Node::CLI::Libvirt::Storage->new;

  my $fail_count = 0;
  for my $disk_param ( @$disk_param_ref ) {
    my $disk_path = $disk_param->{image_path};
    my $disk_size = $disk_param->{size};

    $libvirt_storage->add_by_path( $disk_path );

    # _disk_allocate( $disk_path, $disk_size )
    _disk_make( $disk_path, $disk_size )
      or $fail_count++;

  }
  my $callback_uri = sprintf "http://%s:3000/vps/define/commit/", $config->{callback_host};
  my $callback     = Murakumo_Node::CLI::Job::Callback->new({
                                                               uri           => $callback_uri,
                                                               retry_by_mail => 1,
                                                            });

  my %callback_params = (
                           reserve_uuid => $reserve_uuid,
                           vps_uuid     => $vps_uuid,
                         );


  $callback->set_params(\%callback_params);

  if ($fail_count == 0) {
    $callback->set_result( 1 );
  }     

  # DESTRUCTOR call... following code is not necessary
  # if (! $callback->call(\%callback_params)) {
  #   critical("callback /vps/disk/create/ error ", Dumper \%callback_params);
  # }

  return $fail_count == 0;

}

sub remove {
  my ($self, $params) = @_;

  my $vps_uuid   = $params->{uuid};
  my $disks      = $params->{disks};

  my $fail_count = 0;

  require Murakumo_Node::CLI::Libvirt::Storage;
  my $libvirt_storage = Murakumo_Node::CLI::Libvirt::Storage->new;
  for my $disk_path ( @$disks ) {

    warn "add_by_path ( $disk_path )";
    if (! $libvirt_storage->add_by_path( $disk_path )) {
      $fail_count++;
      warn "add_by_path ( $disk_path ) failure";
      next;
    }

    warn "remove disk path: $disk_path";
    my $rename_disk_path = sprintf "%s.%s", $disk_path, $config->{unlink_disk_ext};

    rename $disk_path, $rename_disk_path;
    -e $disk_path and $fail_count++;

  }
  my $callback_uri = sprintf "http://%s:3000/vps/define/remove_commit/", $config->{callback_host};
  my $callback     = Murakumo_Node::CLI::Job::Callback->new({
                                                               uri           => $callback_uri,
                                                               retry_by_mail => 1, 
                                                            });

  my %callback_params = (
                           uuid         => $vps_uuid,
                         );

  $callback->set_params( \%callback_params );
  dumper( \%callback_params );

  if ($fail_count == 0) {
    # $callback_params{result} = 1;
    $callback->set_result( 1 );
  }     

  return $fail_count == 0;

}

sub path_make {
  goto \&_path_make;
}

sub _path_make {
  my $file_path = shift;
  $file_path or return 0;
  my $dirname = dirname $file_path;

  # 既にあれば成功
  -d $dirname and return 1;
  mkpath $dirname, 0755;

}

sub _disk_make {
  my ($file_path, $file_size) = @_;
  # 既に存在するなら成功で返す
  -f $file_path and return 1;
  warn "$file_path (${file_size}kB) is creating by dd";

  local $?;
  _path_make( $file_path );

  my $command   = sprintf "qemu-img create -f raw %s %dK", $file_path, $file_size;
  warn $command;
  my $disk_make = run(
                       command => $command,
                       timeout => 600,
                       verbose => 1,
                     );
  return $disk_make;
}

sub clone {
  goto &clone_for_image;
}

sub clone_for_image {
  my ($self, $argv) = @_;
  warn Dumper $argv;

  no strict 'refs';
  # src_uuid と dst_hostname は、必須
  my (
       $src_uuid,
       $dst_hostname,
       $mac,
       $ip,
       $mask,
       $gw,
       $reserve_uuid,
       $dst_uuid,       # option
       $src_image_path, # option 
       $dst_image_path, # option
       $callback_host,  # option
       $set_network,    # option
      )
      = (
          $argv->{src_uuid},
          $argv->{dst_hostname},
          $argv->{mac},
          $argv->{ip},
          $argv->{mask},
          $argv->{gw},
          $argv->{reserve_uuid},
          $argv->{dst_uuid},
          $argv->{src_image_path},
          $argv->{dst_image_path},
          $argv->{callback_host},
          $argv->{set_network},
        );

  my $use_public = exists $argv->{public};

  $self->maked_file( $dst_image_path );

  $callback_host ||= $config->{callback_host};
  my $callback_uri = sprintf "http://%s:3000/vps/define/commit/", $callback_host;
  my $callback     = Murakumo_Node::CLI::Job::Callback->new({
                                                               uri           => $callback_uri,
                                                               retry_by_mail => 1,,
                                                             });
  my %callback_params = (
                           image_path   => $dst_image_path,
                           reserve_uuid => $reserve_uuid,
                           vps_uuid     => $dst_uuid,
                         );
  $callback->set_params( \%callback_params );

  local $@;
  eval {

    require Murakumo_Node::CLI::Libvirt::Storage;
    my $libvirt_storage = Murakumo_Node::CLI::Libvirt::Storage->new;

    $libvirt_storage->add_by_path( $src_image_path );
    $libvirt_storage->add_by_path( $dst_image_path );
    $self->make_image_cloning( $src_image_path, $dst_image_path );

    # ディスクに書き込むパラメータが全てそろっていたら
    if ( $mac and $ip and $mask and $gw and $set_network ) {

      # コピーしたディスクに、ip と mac を書き込み
      # !!!!! まだ ダミー !!!!!
      Murakumo_Node::CLI::Guestfs->new( $config->{guestfs_script_path} )
                                 ->set_network( {
                                                 ip       => $ip,
                                                 mac      => $mac,
                                                 hostname => $dst_hostname,
                                                 drive    => $dst_image_path,
                                                 gw       => $gw,
                                                 mask     => $mask,
                                             } )
      or croak "*** set_network is error";
    }


  };

  my $result = 0;
  if ($@) {
    # 失敗した場合の後片付け
    unlink $dst_image_path;
  } else {
    $result = 1;
    $callback->set_result( $result );
  }

  return $result;
  
}

sub _get_date {
  my $dt = DateTime->now('Asia/Tokyo');
  $dt->strftime("%Y%m%d%H%M%S");
}

sub _cleanup {
  my ($self) = @_;
  my @args   = $self->maked_file; 
  for my $path ( @args ) {
    my $dst_path = sprintf "%s.%s", $path, _get_date();
    rename $path, $dst_path;
  }

}

sub maked_file {
  my ($self, @files) = @_;
  no strict 'refs';
  if (@files > 0) {
    $self->{__maked_file} = \@files;

  } else {
    my $files = exists $self->{__maked_file}
              ? $self->{__maked_file}
              : [];

    return @$files;
  }
}

sub make_image_cloning {
  my ($self, $src_image_path, $dst_image_path) = @_;

  # 既に作成するファイルがある場合はエラー
  -f $dst_image_path and croak "$dst_image_path is already exist";

  _path_make( $dst_image_path );

  # とりあえず、cp...
  my $cmd = "cp --sparse=auto $src_image_path $dst_image_path";

  warn $cmd;
  my $r = system $cmd;

  $r == 0
     or croak "*** make image: $cmd";

  return 1;

}

1;
