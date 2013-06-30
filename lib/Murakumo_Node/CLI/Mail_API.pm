use warnings;
use strict;
use 5.014;

package Murakumo_Node::CLI::Mail_API;
use Carp;
use JSON;

use FindBin;
use lib qq{$FindBin::Bin/../lib};
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
  }, $class;
}

sub post {
  # HTTP POSTのみサポート
  my ($self, $uri, $data, $option) = @_;

  my $sender = exists $option->{sender}
             ? $option->{sender}
             : exists $ENV{LOGNAME}
             ? $ENV{LOGNAME}
             : "root";

  open my $pipe, "| /usr/sbin/sendmail -f$sender $self->{api_to}";
    print {$pipe} "$config->{mail_extra_uri_header_name}: $uri\n";
    print {$pipe} "\n";
    print {$pipe} $data;
  close $pipe;

}

1;
