use strict;
use warnings;

use TheSchwartz;
use Storable;
use File::Basename;
use Parallel::Prefork;
use POSIX;
use App::Daemon qw(daemonize);
{
  no warnings;
  $Storable::Eval= 1;
}

use lib qw(/home/smc/murakumo_node/lib);
use Murakumo_Node::CLI::Job::Work;
use Murakumo_Node::CLI::Job;
use Murakumo_Node::CLI::Utils;

my $config = Murakumo_Node::CLI::Utils->config;

my @params = (
  {
    db_path => $config->{job_db_path},
    class   => 'Murakumo_Node::CLI::Job::Work',
  },
  {
    db_path => $config->{retry_db_path},
    class   => 'Murakumo_Node::CLI::Job::Work',
  },
);

my $pm = Parallel::Prefork->new(
           max_workers       => @params + 0,
           trap_signals      => {
               TERM => 'TERM',
               HUP  => 'TERM',
           },
         );

$App::Daemon::kill_sig = SIGINT;
$App::Daemon::pidfile  = "/var/run/" . basename __FILE__ . ".pid";
$App::Daemon::logfile  = "/var/log/" . basename __FILE__ . ".log";
$App::Daemon::as_user  = "root";

daemonize();

while ( $pm->signal_received ne 'TERM' ) {
  for my $param ( @params ) {
    $pm->start and next;
    my $c = TheSchwartz->new( databases => [ +{ dsn => 'dbi:SQLite:dbname='. $param->{db_path} } ], verbose => 1, );
    
    $c->can_do( $param->{class} );
    $c->work( 1 );
    $pm->finish;
  
  }
}

$pm->wait_all_children;

1;

