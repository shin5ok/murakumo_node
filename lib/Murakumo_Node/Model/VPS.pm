package Murakumo_Node::Model::VPS;
use strict;
use warnings;
use base 'Catalyst::Model::Adaptor';

__PACKAGE__->config( 
    class       => 'Murakumo_Node::CLI::VPS',
    constructor => 'new',
);

1;
