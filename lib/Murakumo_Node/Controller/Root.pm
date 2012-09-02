package Murakumo_Node::Controller::Root;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(namespace => '');

=head1 NAME

Murakumo_Node::Controller::Root - Root Controller for Murakumo_Node

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=head2 index

The root page (/)

=cut

sub stop_error :Private {
  my ( $self, $c ) = @_;
  my $error_message = $c->request->args->[0];

  # エラーをセット
  $c->stash->{result} = "0";

  if (defined $error_message) {
    $c->stash->{message} = $error_message;
    $c->log->warn( $c->stash->{message} );

  }

  return;

}

sub auto :Private {
  my ( $self, $c ) = @_;

  # default値の設定
  $c->stash->{message} = qq{};
  $c->stash->{result}  = 0;

  return 1;

}

# デフォルトのエラー
sub end : ActionClass('RenderView') {
    my ( $self, $c ) = @_;

    if ($@) {
      $c->stash->{result}  = "0";
      if (! exists $c->stash->{message}) {
        $c->log->warn("--- default error -------------");
        $c->stash->{message} = $@;

      }
      return;

    }

    if ((my @errors = @{$c->error}) > 0) {
      $c->stash->{result}  = "0";
      $c->stash->{message} = join ",", @errors;

      $c->clear_errors;
    }

}

=head2 default

Standard 404 error page

=cut

sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
}

=head2 end

Attempt to render a view, if needed.

=cut

=head1 AUTHOR

shin5ok

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
