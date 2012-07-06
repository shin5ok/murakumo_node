use strict;
use warnings;

package Murakumo_Node::CLI::Job;

use TheSchwartz;
use Carp;
use Data::Dumper;

use Storable;
{
  no warnings;
  $Storable::Deparse = 1;
}

# このへん後日設定ファイルにする
our $dbpath  = '/home/smc/Murakumo_Node/lib/Murakumo_Node/CLI/job.db';
our $dbparam = {
       dsn => 'dbi:SQLite:dbname=' . $dbpath,
    };

sub new {
  my ($class, $args) = @_;

  my %ts_init_args;
  $ts_init_args{verbose}   = exists $ENV{DEBUG};
  $ts_init_args{databases} = [ $dbparam ];

  my $obj = TheSchwartz->new( %ts_init_args );

  $obj or croak __PACKAGE__ . " new error";

  return bless +{ theschwartz => $obj }, $class;
}

sub register {
  my $self = shift;
  my $worker  = shift;
  my $arg_ref = shift || {};

  $worker or croak "*** worker class is empty...";

  {
    no strict 'refs';
    $arg_ref->{_worker_class} = $worker;
  }
warn Dumper $arg_ref;

  #
  return $self->{theschwartz}->insert( 'Murakumo_Node::CLI::Job::Work' => $arg_ref );

}


1;
