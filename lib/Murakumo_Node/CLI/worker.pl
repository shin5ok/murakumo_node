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

my $dbpath = q(/home/smc/Murakumo_Node/lib/Murakumo_Node/CLI/job.db);

my $c = TheSchwartz->new( databases => [ +{ dsn => 'dbi:SQLite:dbname='. $dbpath, } ], verbose => 1, );

use Murakumo_Node::CLI::Job::Work;
$c->can_do('Murakumo_Node::CLI::Job::Work');

#use Murakumo_Node::CLI::Worker_Test2;
# $c->can_do('Murakumo_Node::CLI::Worker_Test2');

$c->work( 1 );

1;

