package Murakumo_Node::Controller::Node;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Murakumo_Node::Controller::Node - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

use Data::Dumper;
use JSON;

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched Murakumo_Node::Controller::Node in Node.');
}

sub setup_node :Local {
  my ($self, $c) = @_;

  my $body = $c->request->body;
  my $params = decode_json <$body>;

  $c->log->info("setup_node called: " . Dumper $params);

  my $br_ref   = $params->{br};
  my $disk_ref = $params->{storage};

  my $vps_model = $c->model('VPS');
  $vps_model->make_bridge_and_storage_pool( { br => $br_ref, storage => $disk_ref } );

  $c->log->info( Dumper +{ br => $br_ref, storage => $disk_ref } );

  $c->stash->{result} = 1;

}


=head1 AUTHOR

A clever guy

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
