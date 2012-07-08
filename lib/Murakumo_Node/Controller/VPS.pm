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

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched Murakumo_Node::Controller::VPS in VPS.');
}

sub boot :Local {
  my ( $self, $c ) = @_;
  # goto &boot_from_xmlfile;
  return $c->forward( 'boot_from_json' );
}

sub boot_from_json :Local{
  my ( $self, $c ) = @_;

  my $body   = $c->request->body;
  my $params = decode_json <$body>;

  warn Dumper $params;
  {
    no strict 'refs';
    for my $param_name ( qw( job_uuid uuid ) ) {
      exists $params->{$param_name}
        or croak "*** $param_name is missing...";
    }
  }

  # job uuid をセット
  # my $param_ref = { job_uuid => $params->{job_uuid} };

  local $@;

  if ($@) {
    warn "EVAL ERROR: ", $@;
    $c->stash->{message} = $@;

  } else {

    my $job_model = $c->model('Job');
    my $r = $job_model->register('VPS::Boot', $params);
    if ($r) {
      $c->stash->{result} = 1;
    } else {
      $c->stash->{message} = sprintf "job regist error(%s)", Dumper $params;
    }

  }

  # return $c->forward( $c->view('JSON') );

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

  my $r = $job_model->register($class, $params);
  if ($r) {
    $c->stash->{result} = 1;
  };

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

}

sub create :Local {
  my ( $self, $c ) = @_;
  my $body   = $c->request->body;
  my $params = decode_json <$body>;

  # $c->stash->{result} = 0;

  my $job_model = $c->model('Job');

  my $r = $job_model->register('VPS::Disk::Create', $params);
  warn $r;
  if ($r) {
    $c->stash->{result} = 1;
  };

  # return $c->forward( $c->view('JSON') );

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

  # return $c->forward( $c->view('JSON') );

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

  # return $c->forward( $c->view('JSON') );

}

sub clone :Local {
  my ( $self, $c ) = @_;
  my $body   = $c->request->body;
  my $params = decode_json <$body>;

  my $job_model = $c->model('Job');

  local $@;
  eval {
    no strict 'refs';

    # .-------------------------------------+--------------------------------------.
    # | Parameter                           | Value                                |
    # +-------------------------------------+--------------------------------------+
    # | assign_ip                           | 1                                    |
    # | gw                                  | 10.0.0.1                             |
    # | ip                                  | 10.0.0.64                            |
    # | job_uuid                            | E83DEB80-7EED-11E1-B7FC-7D2BED8143B2 |
    # | mask                                | 255.255.255.0                        |
    # | org_uuid                            | 1ca2dd1a-5a1f-29a2-6e4a-62f2f00be567 |
    # | project_id                          | 111                                  |
    # '-------------------------------------+--------------------------------------'
    my @param_names = qw(
                          org_uuid
                          dst_uuid
                          project_id
                         );

    # 必須は dst_name、org_name、project_id
    # 任意に、dst_image_path、org_iamge_path、xml_path
    for my $name ( @param_names ) {
      exists $params->{$name}
        or croak "*** $name is empty";
    }
  };

  if (! $@) {
    my $r = $job_model->register('VPS::Clone', $params);
    if ($r) {
      $c->stash->{result} = 1;
    };
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
