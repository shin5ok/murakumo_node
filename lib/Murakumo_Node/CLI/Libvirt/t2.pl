
use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use JSON;
use lib qw(/home/smc/Murakumo_Node/lib);
use Murakumo_Node::CLI::VPS;

# my $v = Murakumo_Node::CLI::VPS->new;


chomp ( my $uuid = `uuidgen` );
my @disks = (
  {
    image_path => "/vm/111/v10001.img",
  },
  {
    image_path => "/vm/111/v5002.img",
    driver  => 'ide',
  },
  {
    image_path => "/vm/111/v3001.img",
    driver  => 'virtio',
  },
  {
    image_path => "/vm/111/v3006.img",
    driver  => 'ide',
  },
  {
    image_path => "/vm/111/v3004.img",
    driver  => 'virtio',
  },
  {
    image_path => "/vm/111/v3005.img",
    driver  => 'virtio',
  },
  {
    image_path => "/vm/111/v999.img",
    driver  => 'ide',
  },
);
my @interfaces = (
  {
    mac => '00:11:44:dd:ff:92',
    bridge => 'br0308',
    driver => 'virtio',
    ip     => '172.24.1.243',
  },
  {
    mac => '00:11:44:dd:ff:93',
    bridge => 'br0431',
    driver => 'virtio',
    ip     => '10.1.2.42',
  },
);

my $p = {
  cpu        => 2,
  uuid       => $uuid,
  memory     => 1024000,
  disks      => \@disks,
  interfaces => \@interfaces,
  clock      => 'utc',
};

my $json = encode_json { root => $p };
my $req  = POST 'http://127.0.0.1:3000/vps/boot/', [ { json => $json } ];
# my $req  = POST 'http://127.0.0.1:3000/vps/boot_from_json/', [ { json => $json } ];
my $ua   = LWP::UserAgent->new;
$ua->timeout( 5 );
my $response = $ua->request( $req );

print $response->content,"\n";
