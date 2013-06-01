package Murakumo_Node::Controller::VPS;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }
use Path::Class;

=head1 NAME

Murakumo_Node::Controller::VPS - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

use Data::Dumper;
use Carp;
use JSON;
use URI::Escape;
use Murakumo_Node::CLI::Utils;

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched Murakumo_Node::Controller::VPS in VPS.');
}

sub boot :Local {
  my ( $self, $c ) = @_;
  return $c->forward( 'boot_from_json' );
}

sub boot_from_json :Local {
  my ( $self, $c ) = @_;

  my $body   = $c->request->body;
  my $params = decode_json <$body>;

  {
    no strict 'refs';
    for my $param_name ( qw( job_uuid ) ) {
      exists $params->{$param_name}
        or $c->detach("/stop_error", ["*** $param_name is missing..."]);
    }
  }

  local $@;

  if ($@) {
    $c->stash->{message} = $@;
    $c->log->warn( $c->stash->{message} );

  } else {

    my $job_model = $c->model('Job');
    my $r = $job_model->register('VPS::Boot', $params);
    if ($r) {
      $c->stash->{result} = 1;
    } else {
      $c->stash->{message} = sprintf "job regist error(%s)", Dumper $params;
    }

  }

}

sub shutdown :Local {
  my ( $self, $c ) = @_;
  $c->forward('_operation', ['VPS::Shutdown']);

}

sub terminate :Local {
  my ( $self, $c ) = @_;
  $c->forward('_operation', ['VPS::Terminate']);
}

sub _operation :Private {
  my ( $self, $c ) = @_;

  my $class = $c->request->args->[0];

  my $body   = $c->request->body;
  my $params = decode_json <$body>;

  my $id       = $params->{'uuid'};
  my $job_uuid = $params->{'job_uuid'};

  my $job_model = $c->model('Job');

  $c->log->info("job register: $class " . Dumper $params);

  my $r = $job_model->register($class, $params);
  if ($r) {
    $c->stash->{result} = 1;
  }

}

sub cdrom :Local {
  my ($self, $c) = @_;
  my $body   = $c->request->body;
  my $params = decode_json <$body>;

  my $vps_uuid   = $params->{uuid};
  my $cdrom_path = $params->{cdrom_path};
  my $model = $c->model('CDROM');

  if (! $model->change( $vps_uuid, $cdrom_path )) {
    $c->stash->{message} = "cdrom $cdrom_path set failure";
  } else {
    my $mode_result = $cdrom_path ? "attach($cdrom_path)" : "detach";
    $c->stash->{message} = "cdrom $mode_result";
    $c->stash->{result}  = 1;
  }

  $c->log->info( $c->stash->{message} );

}

sub create :Local {
  my ( $self, $c ) = @_;
  my $body   = $c->request->body;
  my $params = decode_json <$body>;

  # $c->stash->{result} = 0;

  my $job_model = $c->model('Job');

  my $r = $job_model->register('VPS::Disk::Create', $params);

  if ($r) {
    $c->stash->{result} = 1;
    $c->log->info("vps create job " . Dumper $params);
  }

}

sub remove :Local {
  my ( $self, $c ) = @_;
  my $body   = $c->request->body;
  my $params = decode_json <$body>;

  # $c->stash->{result} = 0;

  my $job_model = $c->model('Job');

  my $r = $job_model->register('VPS::Disk::Remove', $params);
  if ($r) {
    $c->stash->{result} = 1;
  };

  $c->log->info("vps remove job " . Dumper $params);

}

sub migration :Local {
  my ( $self, $c ) = @_;

  my $body   = $c->request->body;
  my $params = decode_json <$body>;

  my $job_model = $c->model('Job');

  my $r = $job_model->register('VPS::Migration', $params);
  if ($r) {
    $c->stash->{result} = 1;
  };

  $c->log->info("vps migration job " . Dumper $params);

}

sub clone :Local {
  my ( $self, $c ) = @_;
  my $body   = $c->request->body;
  my $params = decode_json <$body>;

  my $job_model = $c->model('Job');

  my $r = $job_model->register('VPS::Clone', $params);
  if ($r) {
    local $Data::Dumper::Terse = 1;
    $c->log->info("vps clone job " . Dumper $params);
    $c->stash->{result} = 1;
  } else {
    $c->stash->{error} = $@;
  }

}

=head1 AUTHOR

shin5ok

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
