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

use lib qw(/home/smc/Murakumo_Node/lib);
use Murakumo_Node::CLI::Job;

my $progname = basename __FILE__;
newdaemon(
  progname   => $progname,
  pidfile    => '/var/run/' .  $progname . ".pid",
);

sub gd_preconfig {}

sub gd_run {

  my $dbpath = q(/home/smc/Murakumo_Node/lib/Murakumo_Node/CLI/job.db);
  
  my $c = TheSchwartz->new( databases => [ +{ dsn => 'dbi:SQLite:dbname='. $dbpath, } ], verbose => 0, );
  
  eval qq{use Murakumo_Node::CLI::Job::Work;};
  $c->can_do('Murakumo_Node::CLI::Job::Work');
  
  $c->work( 1 );

}

1;

