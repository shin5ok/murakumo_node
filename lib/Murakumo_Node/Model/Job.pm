package Murakumo_Node::Model::Job;
use strict;
use warnings;
use base 'Catalyst::Model::Factory';
# use base 'Catalyst::Model::Adaptor';

__PACKAGE__->config( 
    class       => 'Murakumo_Node::CLI::Job',
    constructor => 'new',
);

1;
