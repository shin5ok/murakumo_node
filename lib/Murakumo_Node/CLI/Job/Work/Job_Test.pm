use strict;
use warnings;
package Murakumo_Node::CLI::Job::Work::Job_Test;
use Data::Dumper;

sub work {
  my $self = shift;
  my $job  = shift;
  no strict 'refs';
  my $word = $job->arg->{word} || "no word";
  open my $f, "| /usr/sbin/sendmail kawano\@nttsmc.com";
  print {$f} "Subject: " . __PACKAGE__ . "\n";
  print {$f} "\n";
  print {$f} "word: $word\n";
  print {$f} Dumper $job;
  close $f;
  $job->completed;
  
}

1;
