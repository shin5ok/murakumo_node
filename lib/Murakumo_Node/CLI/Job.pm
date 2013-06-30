use strict;
use warnings;
use 5.014;

package Murakumo_Node::CLI::Job 0.01;

use TheSchwartz;
use Carp;
use Data::Dumper;

use Storable;
{
  no warnings;
  $Storable::Deparse = 1;
}
use FindBin;
use lib qq{$FindBin::Bin/../lib};
use Murakumo_Node::CLI::Utils;

my $config   = Murakumo_Node::CLI::Utils->config;

sub new {
  my ($class, $args) = @_;

  my %ts_init_args;
  $ts_init_args{verbose} = exists $ENV{DEBUG};

  my $db_path = exists $args->{db_path}
              ? $args->{db_path}
              : $config->{job_db_path};

  $ts_init_args{databases} = [ { dsn => 'dbi:SQLite:dbname=' . $db_path } ];

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

  return $self->{theschwartz}->insert( 'Murakumo_Node::CLI::Job::Work' => $arg_ref );

}


1;
