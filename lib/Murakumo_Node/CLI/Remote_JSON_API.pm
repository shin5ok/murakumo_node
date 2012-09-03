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
  my $query   = shift || {};

  my $uri_query = +{URI->new( $api_uri )->query_form};

  # 既存のuri の query を 引数で上書き
  if (keys %$uri_query > 0) {
    %$query = ( %$uri_query, %$query );
  }

  return bless +{
           api_uri => $api_uri,
           query   => $query,
         }, $class;
}

sub query {
  my $self  = shift;
  my $query = shift;

  if ($query) {
    if (ref $self->{query} eq 'HASH') {
      %$query = (%{$self->{query}}, %$query);
    }
    $self->{query} = $query;
  }

  return $self->{query};

}

sub get {
  my ($self, $uri_path, $params) = @_;
  no strict 'refs';
  my $api_uri = $self->{api_uri} || $config->{api_uri};
  my $uri = URI->new( $api_uri ."/". $uri_path );

  my $query = $self->query( $params );

  if (! exists $query->{key}) {
    my $key = $utils->get_api_key;
    my %new_query = (
      name      => hostname(),
      key       => $key->{api_key},
      node_uuid => $key->{node_uuid},
    );
    %$query = (%$query, %new_query);
  }

  $uri->query_form( %{$query} );

  my $response = $wwwua->get( $uri );

  if ($response->is_success) {
    return $response;
  } else {
    return undef;
  }

}

sub json_post {

  my ($self, $uri_path, $params, $option_ref) = @_;
  $uri_path ||= "";

  no strict 'refs';
  my $uri;
  if ($uri_path =~ m{^https?://}) {
    $uri = URI->new( $uri_path );
  } else {
    my $api_uri = $self->{api_uri} || $config->{api_uri};
    $uri = URI->new( $api_uri ."/". $uri_path );
  }

  my $query = $self->query( $params );
  if (! exists $query->{key}) {
    my $key = $utils->get_api_key;
    my %new_query = (
      name      => hostname(),
      key       => $key->{api_key},
      node_uuid => $key->{node_uuid},
    );
    %$query = (%$query, %new_query);
  }

  $uri->query_form( %{$query} );

  if (! exists $option_ref->{encoded}) {
    eval {
      $params = encode_json $params;
    }
  }

  my $request = HTTP::Request->new( 'POST', $uri );
  $request->header('Content-Type' => 'application/json');
  $request->content( $params );

  my $response;
  eval {
    $response = $wwwua->request( $request );
    warn $response->code;
  };
  return $response;

}


sub post {
  my ($self, $uri_path, $params) = @_;
  dumper($params);
  no strict 'refs';
  my $api_uri = $self->{api_uri} || $config->{api_uri};
  my $uri = URI->new( $api_uri ."/". $uri_path );

  my $request = POST $uri, [ %$params ];
  my $response = $wwwua->request( $request );
  # warn "----- post ---------------";
  # warn $response->content;
  # warn "--------------------------";

  # warn $response;
  return $response;

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
