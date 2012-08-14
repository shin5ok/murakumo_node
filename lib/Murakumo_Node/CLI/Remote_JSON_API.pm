use strict;
use warnings;

package Murakumo_Node::CLI::Remote_JSON_API 0.01;

use LWP::UserAgent;
use HTTP::Request::Common qw( GET POST );
use Sys::Hostname;
use URI;
use JSON;
use Data::Dumper;
use FindBin;
use lib qq{$FindBin::Bin/../lib};
use Murakumo_Node::CLI::Utils;

our $utils  = Murakumo_Node::CLI::Utils->new;
our $config = $utils->config;
our $wwwua  = do { my $ua = LWP::UserAgent->new; $ua->timeout(10); $ua };

sub new {
  my $class   = shift;
  my $api_uri = shift;
  my $query   = shift || undef; # uri に 追加するquery
  return bless +{
           api_uri => $api_uri,
           query   => $query,
         }, $class;
}

sub query {
  my $self  = shift;
  my $query = shift;
  if ($query) {
    $self->{query} = $query;
  }
  return $self->{query};
}

sub get {
  my ($self, $uri_path, $param) = @_;
  no strict 'refs';
  my $api_uri = $self->{api_uri} || $config->{api_uri};
  my $uri = URI->new( $api_uri ."/". $uri_path );

  my $query = $self->query;
  if (! exists $query->{key}) {

    my $key = $utils->get_api_key;
    my $api_valid_query = {
      name      => hostname(),
      key       => $key->{api_key},
      node_uuid => $key->{node_uuid},
    };

    warn Dumper $param;

    %$param = ( %$param, %{$api_valid_query} );
    warn Dumper $param;

  }

  $uri->query_form(%$param);

  my $response = $wwwua->get( $uri );
  warn $uri;

  if ($response->is_success) {
    return $response;
  } else {
    return undef;
  }

}

sub json_post {

  my ($self, $uri_path, $params) = @_;
  $uri_path ||= "";

  no strict 'refs';
  my $uri;
  if ($uri_path =~ m{^https?://}) {
    $uri = URI->new( $uri_path );
  } else {
    my $api_uri = $self->{api_uri} || $config->{api_uri};
    $uri = URI->new( $api_uri ."/". $uri_path );
  }

  my $query = $self->query;
  if (! exists $query->{key}) {
    my $key = $utils->get_api_key;
    $query = {
      name      => hostname(),
      key       => $key->{api_key},
      node_uuid => $key->{node_uuid},
    };
  }
  $uri->query_form( %{$query} );

  warn "----- json_post ------------------------";
  warn $uri;
  warn Dumper $params;
  warn "----------------------------------------";

  my $request = HTTP::Request->new( 'POST', $uri );
  $request->header('Content-Type' => 'application/json');
  $request->content( encode_json $params );

  my $response = $wwwua->request( $request );
  if ($response->is_success) {
    return $response;

  } else {
    warn "*** http request error for $uri";
    warn $response->content;
    return undef;

  }

}


sub post {
  my ($self, $uri_path, $params) = @_;
  dumper($params);
  no strict 'refs';
  my $api_uri = $self->{api_uri} || $config->{api_uri};
  my $uri = URI->new( $api_uri ."/". $uri_path );

  my $request = POST $uri, [ %$params ];
  my $response = $wwwua->request( $request );
  warn "----- post ---------------";
  warn $response->content;
  warn "--------------------------";

  if ($response->is_success) {
    return $response;
  } else {
    warn $response->code;
    return undef;
  }

}



__END__
496 sub _www_get {
497   my $wwwua = LWP::UserAgent->new;
498   $wwwua->timeout( 10 );
499   my ($uri_string, %param) = @_;
500   my $uri = URI->new( $uri_string );
501   %param and $uri->query_form( \%param );
502
503   return $wwwua->get( $uri );
504 }
505
506 sub _www_post {
507   my $uri   = shift;
508   my $param = shift;
509   my $wwwua = LWP::UserAgent->new;
510   $wwwua->timeout( 10 );
511   my $request = POST $uri, [ $param ];
512   warn Dumper $request;
513   return $wwwua->request( $request );
514 }



1;
