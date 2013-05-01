#!/usr/bin/env perl
# IMPORTANT: if you delete this file your app will not work as
# expected.  You have been warned.
use inc::Module::Install 1.02;
use Module::Install::Catalyst; # Complain loudly if you don't have
                               # Catalyst::Devel installed or haven't said
                               # 'make dist' to create a standalone tarball.

name 'Murakumo_Node';
all_from 'lib/Murakumo_Node.pm';

requires 'Catalyst::Runtime' => '5.90007';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Action::RenderView';
requires 'Moose';
requires 'namespace::autoclean';
requires 'Config::General'; # This should reflect the config file format you've chosen
                 # See Catalyst::Plugin::ConfigLoader for supported formats

requires 'App::Daemon';
requires 'Config::General';
requires 'DateTime';
requires 'File::Path';
requires 'FindBin';
requires 'HTTP::Request::Common
requires 'IPC::Cmd';
requires 'JSON';
requires 'LWP::UserAgent';
requires 'Log::Log4perl::Catalyst';
requires 'Log::Log4perl';
requires 'Moose';
requires 'Parallel::Prefork';
requires 'Path::Class';
requires 'Storable';
requires 'Sys::Virt';
requires 'Template';
requires 'TheSchwartz::Worker';
requires 'TheSchwartz';
requires 'Parallel::Prefork';
requires 'Try::Tiny';
requires 'XML::TreePP';

test_requires 'Test::More' => '0.88';
catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;


