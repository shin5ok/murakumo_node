package Murakumo_Node::CLI::Job::Work::Worker_Test2;

use strict;
use warnings;

use Data::Dumper;
use Carp;

*work = \&work2;
sub syslog_write {
  use Sys::Syslog qw(:DEFAULT setlogsock);
  setlogsock 'unix';
  openlog __FILE__, 'local0';
  syslog 'notice', shift;
  closelog;
}

sub work2 {
  my $self = shift;
  my $job  = shift;
  syslog_write( Dumper $job );

  use lib q(/home/smc/Murakumo_Node/lib);
  use Murakumo_Node::CLI::Node;
  use Murakumo_Node::CLI::VPS;

  my $mode;
  {
    no strict 'refs';
    $mode = $job->arg->{mode} || "shutdown";
  }

  # 全vps id取得
  # my @ids = Murakumo_Node::CLI::Node->new->list_vps_ids;

  my $id = $job->arg->{id};
  my $vps_obj = Murakumo_Node::CLI::VPS->new( { id => $id } );

  syslog_write("$id is $mode");
  $vps_obj->$mode;

  $job->completed;
  
}

sub work1 {
  my $self = shift;
  my $job  = shift;
  no strict 'refs';
  my $word = $job->arg->{word} || "no word";
  open my $f, "| /usr/sbin/sendmail kawano\@nttsmc.com";
  print {$f} "Subject: " . __PACKAGE__ . "\n";
  print {$f} "\n";
  print {$f} "v\n";
  print {$f} "word: $word\n";
  print {$f} Dumper $job;
  close $f;
  $job->completed;
  
}

1;
