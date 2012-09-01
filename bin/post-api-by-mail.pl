#!/usr/bin/murakumo-perl
use warnings;
use strict;
use FindBin;
use Email::MIME;
use Data::Dumper;

use lib qq{$FindBin::Bin/../lib};
use lib qw(/home/smc/murakumo/lib);
use Murakumo_Node::CLI::Utils;
use Murakumo_Node::CLI::Remote_JSON_API;

my $config = Murakumo_Node::CLI::Utils->config;

sub tlog{
  use Sys::Syslog qw(:DEFAULT setlogsock);
  openlog __FILE__, "ndelay", "local0";
  setlogsock "unix";
  my $log = shift;
  syslog "info", "(" .__LINE__.") ". $log;
  closelog;

}

eval {
  local $SIG{ALRM} = sub { _exit(75); };
  alarm 10;

  my $content = qq{};
  while (<STDIN>) {
    $content .= $_;
  }

  my $email = Email::MIME->new ( $content );
  my $uri   = $email->header( $config->{mail_extra_uri_header_name} );

  if (! $uri) {
    warn "uri get error";
    _exit(75)
  }

  tlog($uri);

  my $json_api = Murakumo_Node::CLI::Remote_JSON_API->new( $uri );
  tlog($email->body);

  my $response = $json_api->json_post( '', $email->body, { encoded => 1 } );

  tlog($response->code);
  if ( ! $response->is_success  ) {
    my $error = sprintf << "_RESULT_", $uri, $response->code;
json_post to %s, code: %d
_RESULT_
    tlog($error);
    _exit(75);
  }

  alarm 0;

};

alarm 0;

tlog($@) if $@;

_exit(0);

sub _exit {
  my $exit_code = shift;
  my @callers = caller;
  tlog("##### exit $exit_code($callers[2])");
  exit $exit_code;
}
