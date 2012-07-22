use warnings;
use strict;

package Murakumo_Node::CLI::VPS::Disk;
use Path::Class;
use Carp;
use IPC::Open3;
use File::Basename;
use File::Path qw(mkpath);
use Data::Dumper;

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
  my $project_id     = $params->{project_id};
  # my $job_uuid       = $params->{job_uuid};
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
    _dd_make( $disk_path, $disk_size )
      or $fail_count++;

  }
  my $callback_uri = sprintf "http://%s:3000/vps/define/commit/", $config->{callback_host};
  my $callback     = Murakumo_Node::CLI::Job::Callback->new({
                                                               uri           => $callback_uri,
                                                               retry_by_mail => 1,
                                                            });

  my %callback_params = (
                           project_id   => $project_id,
                           # job_uuid     => $job_uuid,
                           reserve_uuid => $reserve_uuid,
                           # result       => 0, # デフォルト失敗
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
  warn Dumper $params;

  my $project_id = $params->{project_id};
  my $vps_uuid   = $params->{uuid};
  my $disks      = $params->{disks};

  my $fail_count = 0;
  warn "--- remove ---";
  warn Dumper $params;
  warn "--------------";

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
                           project_id   => $project_id,
                         );

  $callback->set_params( \%callback_params );
  dumper( \%callback_params );

  if ($fail_count == 0) {
    # $callback_params{result} = 1;
    $callback->set_result( 1 );
  }     

  # DESTRUCTOR call... following code is not necessary
  # if (! $callback->call(\%callback_params)) {
  #   critical("callback /vps/disk/remove/ error ", Dumper \%callback_params);
  # }

  warn "fail count > $fail_count";
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

sub _disk_allocate {
  my ($file_path, $file_size) = @_;
  # 既に存在するなら成功で返す
  -f $file_path and return 1;
  warn "$file_path (${file_size}kB) is creating by fallocate";
  local $?;
  _path_make( $file_path );
  warn "fallocate -l $file_size $file_path";
  system "fallocate -l $file_size $file_path";
  return $? == 0;

}

sub _dd_make {
  my ($file_path, $file_size) = @_;
  # 既に存在するなら成功で返す
  -f $file_path and return 1;
  warn "$file_path (${file_size}kB) is creating by dd";
  local $?;
  _path_make( $file_path );
  system "dd if=/dev/zero of=$file_path bs=1024 count=$file_size";
  return $? == 0;
}

sub clone {
  goto &clone_for_image;
}

sub clone_for_image {
  my ($self, $argv) = @_;
  warn Dumper $argv;

  no strict 'refs';
  # 前の2つと project_idは必須
  my (
       $org_uuid,
       $project_id, 
       # $job_uuid,
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
          $argv->{org_uuid},
          $argv->{project_id},
          # $argv->{job_uuid},
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

  my $template_dirname = $project_id;

  if ($use_public) {
    $template_dirname = $config->{template_dirname};

  }

  $src_image_path ||= file(
                           $vm_root,
                           $template_dirname,
                           $org_uuid . ".img",
                          )->absolute;

  $dst_image_path ||= file(
                         $vm_root,
                         $project_id,
                         $dst_uuid . ".img"
                        )->absolute;

  $self->maked_file( $dst_image_path );

  $callback_host ||= $config->{callback_host};
  my $callback_uri = sprintf "http://%s:3000/vps/define/commit/", $callback_host;
  my $callback     = Murakumo_Node::CLI::Job::Callback->new({
                                                               uri           => $callback_uri,
                                                               retry_by_mail => 1,,
                                                             });
  my %callback_params = (
                           image_path   => $dst_image_path,
                           project_id   => $project_id,
                           # job_uuid     => $ob_uuid, # job uuid を切り離す
                           reserve_uuid => $reserve_uuid,
                           vps_uuid     => $dst_uuid,
                         );
  $callback->set_params( \%callback_params );

  local $@;
  eval {

    if (! $project_id) {
      croak "project id is require";
    }

    # NECのディスクを操作するため、処理を切り離すように別クラスにする
    # 失敗したら例外を出すこと！

    require Murakumo_Node::CLI::Libvirt::Storage;
    my $libvirt_storage = Murakumo_Node::CLI::Libvirt::Storage->new;

    $libvirt_storage->add_by_path( $src_image_path );
    $libvirt_storage->add_by_path( $dst_image_path );
    $self->make_image_cloning( $src_image_path, $dst_image_path );


    # warn qq( $mac and $ip and $mask and $gw );
    # ディスクに書き込むパラメータが全てそろっていたら
    if ( $mac and $ip and $mask and $gw and $set_network ) {

      # コピーしたディスクに、ip と mac を書き込み
      # !!!!! まだ ダミー !!!!!
      Murakumo_Node::CLI::Guestfs->new->set_network( {
                                                       ip       => $ip,
                                                       mac      => $mac,
                                                       hostname => "", # 空で指定
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

  # DESTRUCTOR call... following code is not necessary
  # if (! $callback->call(\%callback_params)) {
  #   warn "callback error: ", Dumper \%callback_params;
  #   critical("callback /vps/define/clone callback error ", Dumper \%callback_params);
  # }

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
  my ($self, $org_image_path, $dst_image_path) = @_;

  # 既に作成するファイルがある場合はエラー
  -f $dst_image_path and croak "$dst_image_path is already exist";

  _path_make( $dst_image_path );

  # make disk
  # create_disk_cmd = "#{qemu_img} create -b #{org_disk_path} -f #{org_disk_type} #{new_disk_path}"
  # my $cmd = "$qemu_img_cmd create -b $org_image_path -f qcow2 $dst_image_path";

  # とりあえず、cp...
  my $cmd = "cp $org_image_path $dst_image_path";
  # my $cmd = "cp -a $org_image_path $dst_image_path";

  warn $cmd;
  my $r = system $cmd;

  $r == 0
     or croak "*** make image: $cmd";

  return 1;

}

1;
__END__
$VAR1 = {
          'domain' => {
                        'on_poweroff' => 'destroy',
                        '-type' => 'kvm',
                        'features' => {
                                        'apic' => undef,
                                        'acpi' => undef,
                                        'pae' => undef
                                      },
                        'name' => 't005',
                        'currentMemory' => '524288',
                        'on_reboot' => 'restart',
                        'uuid' => 'f0982940-5058-6ac3-c7c8-6d7b19e69e10',
                        'os' => {
                                  'boot' => [
                                              {
                                                '-dev' => 'hd'
                                              },
                                              {
                                                '-dev' => 'cdrom'
                                              }
                                            ],
                                  'type' => {
                                              '#text' => 'hvm',
                                              '-machine' => 'rhel6.1.0',
                                              '-arch' => 'x86_64'
                                            },
                                  'bootmenu' => {
                                                  '-enable' => 'no'
                                                }
                                },
                        'devices' => {
                                       'video' => {
                                                    'model' => {
                                                                 '-type' => 'cirrus',
                                                                 '-heads' => '1',
                                                                 '-vram' => '9216'
                                                               },
                                                    'address' => {
                                                                   '-slot' => '0x02',
                                                                   '-bus' => '0x00',
                                                                   '-type' => 'pci',
                                                                   '-function' => '0x0',
                                                                   '-domain' => '0x0000'
                                                                 }
                                                  },
                                       'input' => {
                                                    '-bus' => 'ps2',
                                                    '-type' => 'mouse'
                                                  },
                                       'disk' => [
                                                   {
                                                     'target' => {
                                                                   '-bus' => 'ide',
                                                                   '-dev' => 'hdc'
                                                                 },
                                                     'readonly' => undef,
                                                     '-type' => 'file',
                                                     '-device' => 'cdrom',
                                                     'address' => {
                                                                    '-unit' => '0',
                                                                    '-bus' => '1',
                                                                    '-type' => 'drive',
                                                                    '-controller' => '0'
                                                                  },
                                                     'driver' => {
                                                                   '-name' => 'qemu',
                                                                   '-type' => 'raw'
                                                                 }
                                                   },
                                                   {
                                                     'source' => {
                                                                   '-file' => '/vm/111/t005.img'
                                                                 },
                                                     'target' => {
                                                                   '-bus' => 'virtio',
                                                                   '-dev' => 'vda'
                                                                 },
                                                     '-type' => 'file',
                                                     '-device' => 'disk',
                                                     'address' => {
                                                                    '-slot' => '0x05',
                                                                    '-bus' => '0x00',
                                                                    '-type' => 'pci',
                                                                    '-function' => '0x0',
                                                                    '-domain' => '0x0000'
                                                                  },
                                                     'driver' => {
                                                                   '-name' => 'qemu',
                                                                   '-type' => 'raw'
                                                                 }
                                                   }
                                                 ],
                                       'serial' => {
                                                     'target' => {
                                                                   '-port' => '0'
                                                                 },
                                                     '-type' => 'pty'
                                                   },
                                       'console' => {
                                                      'target' => {
                                                                    '-type' => 'serial',
                                                                    '-port' => '0'
                                                                  },
                                                      '-type' => 'pty'
                                                    },
                                       'controller' => {
                                                         '-type' => 'ide',
                                                         '-index' => '0',
                                                         'address' => {
                                                                        '-slot' => '0x01',
                                                                        '-bus' => '0x00',
                                                                        '-type' => 'pci',
                                                                        '-function' => '0x1',
                                                                        '-domain' => '0x0000'
                                                                      }
                                                       },
                                       'graphics' => {
                                                       '-passwd' => 'smc',
                                                       '-type' => 'vnc',
                                                       '-port' => '-1',
                                                       '-keymap' => 'ja',
                                                       '-listen' => '0.0.0.0',
                                                       '-autoport' => 'yes'
                                                     },
                                       'interface' => [
                                                        {
                                                          'source' => {
                                                                        '-bridge' => 'br0-104'
                                                                      },
                                                          '-type' => 'bridge',
                                                          'model' => {
                                                                       '-type' => 'virtio'
                                                                     },
                                                          'address' => {
                                                                         '-slot' => '0x03',
                                                                         '-bus' => '0x00',
                                                                         '-type' => 'pci',
                                                                         '-function' => '0x0',
                                                                         '-domain' => '0x0000'
                                                                       },
                                                          'mac' => {
                                                                     '-address' => '00:16:36:ba:a6:74'
                                                                   }
                                                        }
                                                      ],
                                       'emulator' => '/usr/libexec/qemu-kvm',
                                       'memballoon' => {
                                                         'address' => {
                                                                        '-slot' => '0x06',
                                                                        '-bus' => '0x00',
                                                                        '-type' => 'pci',
                                                                        '-function' => '0x0',
                                                                        '-domain' => '0x0000'
                                                                      },
                                                         '-model' => 'virtio'
                                                       },
                                       'sound' => {
                                                    'address' => {
                                                                   '-slot' => '0x04',
                                                                   '-bus' => '0x00',
                                                                   '-type' => 'pci',
                                                                   '-function' => '0x0',
                                                                   '-domain' => '0x0000'
                                                                 },
                                                    '-model' => 'ich6'
                                                  }
                                     },
                        'memory' => '524288',
                        'clock' => {
                                     '-offset' => 'utc'
                                   },
                        'vcpu' => '1',
                        'on_crash' => 'restart'
                      }
        };
