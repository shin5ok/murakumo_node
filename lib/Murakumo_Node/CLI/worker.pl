use strict;
use warnings;

use TheSchwartz;
use Storable;
{
  no warnings;
  $Storable::Eval= 1;
}

use lib qw(/home/smc/Murakumo_Node/lib);
use Murakumo_Node::CLI::Job;
use Murakumo_Node::CLI::Utils;

my $config = Murakumo_Node::CLI::Utils->config;
my $dbpath = $config->{job_db_path};

my $c = TheSchwartz->new( databases => [ +{ dsn => 'dbi:SQLite:dbname='. $dbpath, } ], verbose => 1, );

use Murakumo_Node::CLI::Job::Work;
$c->can_do('Murakumo_Node::CLI::Job::Work');

#use Murakumo_Node::CLI::Worker_Test2;
# $c->can_do('Murakumo_Node::CLI::Worker_Test2');

$c->work( 1 );

1;

