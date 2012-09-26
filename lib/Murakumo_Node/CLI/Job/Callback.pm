use strict;
use warnings;
package Murakumo_Node::CLI::Job::Callback;
use LWP::UserAgent;
use JSON;
use HTTP::Request::Common qw(POST GET);
use Data::Dumper;
use Sys::Hostname;
use Carp;


sub new {
  my $class    = shift;
  my $args_ref = shift;

  my $obj = bless $args_ref, $class;

  {
    no strict 'refs';
    $obj->{called} = 0;

    my $params = exists $args_ref->{params}
               ? $args_ref->{params}
               : {};

    # params value for callback initialize...
    $obj->set_params( $params );

    # result is default false( 0 )
    $obj->set_result( 0 );

  }

  return $obj;
}

sub set_params {
  my $self   = shift;
  my $params = shift || {};
  $self->{params} = $params;
}

sub set_result {
  my $self  = shift;
  my $value = shift;
  { 
    no strict 'refs';
    $self->{params}->{result} = $value;
  }
}

sub set_ok {
  shift->result(1);
}

sub call {
  my ($self, $params) = @_;

  $params ||= $self->{params};

  # 呼んだ
  $self->{called} = 1;

  no strict 'refs';
  my $callback_func = sub {
    my $arg_ref          = shift;
    my ( $uri, $params ) = @$arg_ref;

    warn "--- CALLBACK called ---------";
    warn "uri: " . $uri;
    warn Dumper $params;
    warn "-----------------------------";

    require Murakumo_Node::CLI::Remote_JSON_API;
    my $api = Murakumo_Node::CLI::Remote_JSON_API->new;

    local $Data::Dumper::Terse = 1;

    no strict 'refs';
    my $response = $api->json_post($uri, $params);
    if ($response and $response->is_success) {
      my $r;
      eval {
        $r = decode_json $response->content;
      };
      return $r->{result};

    } else {
      return 0;
    }
  };

  if (! $callback_func->([ $self->{uri}, $params ]) ) {

    no strict 'refs';
    if ( ! $self->{not_retry} ) {

      my $utils   = Murakumo_Node::CLI::Utils->new;
      my $config  = $utils->config;
      my $api_key = $utils->get_api_key;
      my $uri = URI->new ( $self->{uri} );
      $uri->query_form(
                        name      => hostname(),
                        key       => $api_key->{api_key},
                        node_uuid => $api_key->{node_uuid},
                      );

      # メールのapiは権限の問題で、api のkeyを読めないので事前につけておく
      my $params_content = do { encode_json $params };

      require Murakumo_Node::CLI::Mail_API;
      Murakumo_Node::CLI::Mail_API->new ( $config->{mail_api_to} )
                                  ->post( $uri, $params_content );

    }
  }

  return 0;

}

sub is_called {
  return shift->{called};
}

sub DESTROY {
  my ($self) = @_;
  {
    if (! $self->is_called) {
      $self->call
        or croak "callback in DESTRUCTOR is error";

    }
  }
}

1;

