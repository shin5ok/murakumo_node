use warnings;
use strict;

package Murakumo_Node::CLI::Libvirt::Storage 0.02;
use FindBin;
use lib qq{$FindBin::Bin/../lib};
use Murakumo_Node::CLI::Utils;
use Murakumo_Node::CLI::Libvirt;
use Carp;
use Data::Dumper;
use File::Path;
use XML::TreePP ();
use JSON;
use IPC::Cmd qw(run_forked);

use base q(Murakumo_Node::CLI::Libvirt);

use Murakumo_Node::CLI::Libvirt::XML;
use Murakumo_Node::CLI::Remote_JSON_API;

our $mount_timeout = 10;

sub del {
  my ($self, $uuid) = @_;

  my @pools = $self->conn->list_storage_pools;

  my $exist = 0;
  for my $pool (@pools) {
    # 既にないかチェック
    if ($uuid eq $pool->get_uuid_string) {
      $exist = 1;
    }
  }

  if (! $exist) {
    warn "$uuid is not found...return";
    return 1;
  }

  my $pool = $self->conn->get_storage_pool_by_uuid( $uuid );

  # return $pool->undefine;
  return $pool->destroy;

}

sub add_by_path {
  my ($self, $storage_path) = @_;
  warn "storage_path : $storage_path";

  # 先頭から、最初のuuidっぽい文字列を取得
  my ($storage_uuid) = $storage_path =~ / (
                                             [0-9a-z]{8} \-
                                             [0-9a-z]{4} \-
                                             [0-9a-z]{4} \-
                                             [0-9a-z]{4} \-
                                             [0-9a-z]{12}
                                           ) /xoms;
  return $self->add( $storage_uuid );

}

sub add {
  my ($self, $uuid) = @_;
  # 2012年  5月 22日 火曜日 11:53:38 JST
  # <pool type='netfs'>
  #   <name>[% uuid %]</name>
  #   <uuid>[% uuid %]</uuid>
  #   <capacity>0</capacity>
  #   <allocation>0</allocation>
  #   <available>0</available>
  #   <source>
  #     <host name='[% host %]'/>
  #     <dir path='[% export_path %]'/>
  #     <format type='auto'/>
  #   </source>
  #   <target>
  #     <path>[% mount_path %]</path>
  #     <permissions>
  #       <mode>0700</mode>
  #       <owner>-1</owner>
  #       <group>-1</group>
  #     </permissions>
  #  </target>
  # </pool>

  my @pools = $self->conn->list_storage_pools;

  my $mount   = `/bin/mount`;
  my $xml_tpp = XML::TreePP->new;
  POOL:
  for my $pool (@pools) {
    # 既にあるかチェック
    if ($uuid eq $pool->get_uuid_string) {
      my $xml     = $pool->get_xml_description;
      my $xml_ref = $xml_tpp->parse($xml);
      if ($xml_ref->{pool}->{'-type'} eq 'netfs') {
        # mountされているか
        if ($mount =~ m{/$uuid/?}) {
          # されてたらok
          warn "pool list for nfs $uuid ok";
          return 1;
        } else {
          # されてないなら一度消す
          warn "destroy for $uuid";
          warn Dumper $xml_ref;
          $pool->destroy;
          last POOL;
        }
      } else {
        return 1;
      }
    }
  }

  my $api_response = Murakumo_Node::CLI::Remote_JSON_API->new->get('/storage/info/', { uuid => $uuid });
  my $api_result   = decode_json $api_response->content;
  if (exists $api_result->{result} and $api_result->{result} == 1) {
    no strict 'refs';

    my $data = $api_result->{data};

    # ディレクトリを作成
    -e $data->{mount_path} or mkpath $data->{mount_path}, { verbose => 1 };

    my $xml_data = Murakumo_Node::CLI::Libvirt::XML->new->create_storage_xml( $data );

    if (! $self->conn->create_storage_pool( $xml_data )) {
      croak "*** storage pool $uuid create error";
    }
    return 1;

  } else {
    croak "*** storage info $uuid get error...";
  }

}

1;
