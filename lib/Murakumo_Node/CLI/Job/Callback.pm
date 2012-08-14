use strict;
use warnings;
package Murakumo_Node::CLI::Job::Callback;
use LWP::UserAgent;
use JSON;
use HTTP::Request::Common qw(POST GET);
use Data::Dumper;
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
    my $arg_ref = shift;
    my ($uri, $params) = @$arg_ref;
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
    warn "retry callback";
    no strict 'refs';
    if ( ! $self->{not_retry} ) {

      require Murakumo_Node::CLI::Job;
      require Murakumo_Node::CLI::Utils;

      my $config = Murakumo_Node::CLI::Utils->config;
      my $job_model = Murakumo_Node::CLI::Job->new({ db_path => $config->{retry_db_path} });
      $job_model->register('Retry', { func => $callback_func, func_args => [ $self->{uri}, $params ] });

    }

    # no strict 'refs';
    # if ($self->{retry_by_mail}) {

    #   my $data = $params;

    #   # POST で接続できなかったら、メールで再試行
    #   # 将来、メッセージキューに置き換える
    #   my $config = Murakumo_Node::CLI::Utils->new->config;
    #   require Murakumo_Node::CLI::Mail_API;
    #   Murakumo_Node::CLI::Mail_API->new ( $config->{mail_api_to} )
    #                               ->post( $self->{uri}, $data, { type => "json" } );

    # }
  }

  # warn sprintf "%s %s >>> %s : %s (%s)", __PACKAGE__,
  #                                       $self->{uri},
  #                                       Dumper $params,
  #                                       $response->content || "### ERROR ###",
  #                                       $response->code    || 000;

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

