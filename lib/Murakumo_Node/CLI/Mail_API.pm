use warnings;
use strict;
package Murakumo_Node::CLI::Mail_API;
use Carp;

use lib qw(/home/smc/Murakumo_Node/lib);
use Murakumo_Node::CLI::Utils;

my $config = Murakumo_Node::CLI::Utils->config;

sub new {
  my $class = shift;
  my $to    = shift;
  if (! $to) {
    croak "*** mail to api address must be specified";
  }
  bless {
    api_to => $to,
    type   => 'json', # デフォルトJSON
  }, $class;
}

sub post {
  my ($self, $uri, $data, $option) = @_;

  my $encoded_data = "";
  my $error_string = "";

  if ($option->{type} eq 'xml') {
    local $@;
    eval qq{ use XML::TreePP; };
    eval {
      $encoded_data = XML::TreePP->new( force_array => '*' )->parse( $data );
    };
    $error_string .= $@;
  } else {
    local $@;
    eval qq{ use JSON; };
    eval {
      $encoded_data = JSON::encode_json $data;
    };
    $error_string .= $@;
  }

  my $sender = exists $option->{sender}
             ? $option->{sender}
             : exists $ENV{LOGNAME}
             ? $ENV{LOGNAME}
             : "root";
  my $method = exists $option->{method}
             ? $option->{method}
             : "POST";

  open my $pipe, "| /usr/sbin/sendmail -f$sender $self->{api_to}";
  print {$pipe} "X-API-URI: $uri\n";
  print {$pipe} "X-API-METHOD: $method\n";
  print {$pipe} "\n";
  print {$pipe} $data;
  close $pipe;

  return ! $error_string;

}

1;
