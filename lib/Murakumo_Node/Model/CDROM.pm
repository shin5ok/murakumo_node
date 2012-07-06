package Murakumo_Node::Model::CDROM;
use strict;
use warnings;
use base 'Catalyst::Model::Factory';

__PACKAGE__->config( 
    class       => 'Murakumo_Node::CLI::VPS::CDROM',
    constructor => 'new',
);

1;
