#!perl

use strict;
use warnings;

use Test::More;
use File::Spec;
use File::Basename 'dirname';
use IO::Interactive 'is_interactive';
use Regexp::Common 'URI';
use Data::Dumper;

use lib join '/', File::Spec->splitdir(dirname(__FILE__)), '../lib/';

BEGIN
{
  use_ok('Net::CloudPT');
}

SKIP:
{
  skip 'Not running on an interactive shell.', 1 unless is_interactive;

  print 'What is your consumer key? ';
  my $key = <>; chomp $key;
  like($key, '/[-\w\d]+/', 'The key appears to be valid.');

  print 'What is your consumer secret? ';
  my $secret = <>; chomp $secret;
  like($secret, '/\d+/', 'The secret appears to be valid.');

  my $cloud = Net::CloudPT->new(
      key     => $key,
      secret  => $secret,
    );
  is(ref $cloud, 'Net::CloudPT', 'got a CloudPT interface');

  my $url = $cloud->login;

  like($url, "/$RE{URI}{HTTP}{ -scheme => qr{https?} }/", 'The login process returned an auth URL.');

  print "Authorize this test suite here: '$url'\n";
  print 'What is the verifier PIN? ';
  my $pin = <>; chomp $pin;

  like($pin, '/\d{10}/', 'The PIN is a 10-digit number');

  ok($cloud->authorize( verifier => $pin ), 'Authorized');

  my $data = $cloud->metadata( path => '/', file_limit => 2 );
  is(ref $data, 'HASH', 'Got metadata from the root.');
  print Dumper $data;
}

done_testing;
