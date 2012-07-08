#!/home/smc/bin/perl
use strict;
use warnings;

use File::Basename;
use Sys::Syslog qw(:DEFAULT setlogsock);
use Daemon::Generic;

use TheSchwartz;
use Storable;
{
  no warnings;
  $Storable::Eval= 1;
}

use lib qw(/home/smc/murakumo_node/lib);
use Murakumo_Node::CLI::Job;
use Murakumo_Node::CLI::Utils;

my $config   = Murakumo_Node::CLI::Utils->config;
my $progname = basename __FILE__;
newdaemon(
  progname   => $progname,
  pidfile    => '/var/run/' .  $progname . ".pid",
);

sub gd_preconfig {}

sub gd_run {

  my $dbpath = $config->{job_db_path};
  
  my $c = TheSchwartz->new( databases => [ +{ dsn => 'dbi:SQLite:dbname='. $dbpath, } ], verbose => 0, );
  
  eval qq{use Murakumo_Node::CLI::Job::Work;};
  $c->can_do('Murakumo_Node::CLI::Job::Work');
  
  $c->work( 1 );

}

1;

