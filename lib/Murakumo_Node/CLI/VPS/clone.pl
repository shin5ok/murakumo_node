#!/usr/bin/perl
use warnings;
use strict;

use lib qw( /home/smc/Murakumo_Node/lib );
use Murakumo_Node::CLI::VPS::Clone;

my $s = Murakumo_Node::CLI::VPS::Clone->new;

chomp ( my $uuid     = `uuidgen` );
chomp ( my $job_uuid = `uuidgen` );
$s->clone_for_image(
  {
    src_uuid         => shift,
    # src_image_path => shift,
    # dst_image_path   => 
    job_uuid         => uc $job_uuid,
    ip               => '172.24.135.2',
    mask             => '255.255.255.0',
    gw               => '172.24.135.1',
    project_id       => 111,
    dst_uuid         => $uuid,
    mac              => '01:23:45:f1:ee:81',
  }
);

print "new uuid: ", $uuid,"\n";

