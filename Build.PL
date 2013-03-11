#!/usr/bin/env perl

use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new(
  module_name   => 'Net::CloudPT',
  dist_author   => 'Sérgio Bernardino <code@sergiobernardino.net>',
  dist_abstract => 'Net::CloudPT - A CloudPT interface',
  license       => 'perl',
  requires      => {
    'URI'                   => 0,
    'Carp'                  => 0,
    'JSON'                  => 0,
    'Net::OAuth'            => 0,
    'Data::Random'          => 0,
    'LWP::UserAgent'        => 0,
    'LWP::Protocol::https'  => 0,
  },
  build_requires => {
    'Test::More'      => 0,
    'IO::Interactive' => 0,
    'Regexp::Common'  => 0,
  },
  configure_requires  => { 'Module::Build'  => 0 },
  add_to_cleanup      => [ '*META.*'   ],
);

$build->create_build_script;

