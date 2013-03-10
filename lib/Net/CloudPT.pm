package Net::CloudPT;

use strict;
use warnings;

use Carp qw/carp cluck/;
use JSON;
use Net::OAuth; $Net::OAuth::PROTOCOL_VERSION = Net::OAuth::PROTOCOL_VERSION_1_0A;
use LWP::UserAgent;
use LWP::Protocol::https;
use HTTP::Request::Common;
use Data::Random 'rand_chars';

our $VERSION = '0.01';


sub _nonce { join( '', rand_chars( size => 16, set => 'alphanumeric' )); }

sub new
{
  my $class = shift;

  my %args = @_;
  my $self = bless {
    map { lc $_ => $args{$_} } keys %args
  }, $class;

  $self->{ua} ||= LWP::UserAgent->new;
  $self->{callback_url}   ||= 'oob',
  $self->{request_url}    ||= 'https://cloudpt.pt/oauth/request_token',
  $self->{authorize_url}  ||= 'https://cloudpt.pt/oauth/authorize',
  $self->{access_url}     ||= 'https://cloudpt.pt/oauth/access_token',

  return $self;
}

sub login
{
  my $self = shift;

  my $req = Net::OAuth->request('request token')->new(
    consumer_key        => $self->{key},
    consumer_secret     => $self->{secret},
    request_url         => $self->{request_url},
    request_method      => 'POST',
    signature_method    => 'HMAC-SHA1',
    timestamp           => time,
    nonce               => $self->_nonce,
    callback            => $self->{callback_url},
    callback_confirmed  => 'true',
  );

  $req->sign;

  my $res = $self->{ua}->request(POST $req->to_url);

  if ($res->is_success)
  {
    my $response = Net::OAuth->response('request token')->from_post_body($res->content);
    $self->{request_token}  = $response->token;
    $self->{request_secret} = $response->token_secret;

    cluck "Request Token: '"   . $self->{request_token}   . "'" if ( $ENV{DEBUG} );
    cluck "Request Secret: '"  . $self->{request_secret}  . "'" if ( $ENV{DEBUG} );

    my $authorize = $self->{authorize_url} . '?oauth_token=' . $self->{request_token};
    $authorize .= '&oauth_callback=' . $self->{callback_url}
      if ( defined $self->{callback_url} and $self->{callback_url} ne 'oob' );

    cluck "Authorization URL: '$authorize'" if ( $ENV{DEBUG} );

    return $authorize;
  }
  else
  {
    carp "ERROR: " . $res->status_line;
  }
}

sub auth
{
  my $self = shift;

  my %args = @_; %args = map { lc $_ => $args{$_} } keys %args;

  if ( $args{verifier} )
  {
    my $req = Net::OAuth->request('access token')->new(
      consumer_key      => $self->{key},
      consumer_secret   => $self->{secret},
      request_url       => $self->{access_url},
      request_method    => 'POST',
      signature_method  => 'HMAC-SHA1',
      timestamp         => time,
      nonce             => $self->_nonce,
      callback          => $self->{callback_url},
      token             => $self->{request_token},
      token_secret      => $self->{request_secret},
      verifier          => $args{verifier},
    );

    $req->sign;

    my $res = $self->{ua}->request(POST $req->to_url);

    if ($res->is_success)
    {
      my $response = Net::OAuth->response('access token')->from_post_body($res->content);
      $self->{access_token}  = $response->token;
      $self->{access_secret} = $response->token_secret;

      cluck "Access Token: '"   . $self->{access_token} . "'" if ( $ENV{DEBUG} );
      cluck "Access Secret: '"  . $self->{access_secret} . "'" if ( $ENV{DEBUG} );

      # ok
      return 1;
    }
    else
    {
      carp "ERROR: " . $res->status_line;
    }
  }
  else
  {
    carp "ERROR: Authorization Verifier needed.";
  }
}

=head1 NAME

Net::CloudPT - A CloudPT interface

=head1 SYNOPSYS

This module is a Perl interface to the API for the Portuguese cloud storage
service CloudPT. You can learn more about it at L<http://www.cloudpt.pt>.

Quick start:

    use Net::CloudPT;

    my $cloud = Net::CloudPT->new( key => 'KEY', secret => 'SECRET' );
    $cloud->login;

    # authorize the app, retrieving the verifier PIN...

    $cloud->auth( verifier => $pin );

The particular details regarding the API can be found at L<https://cloudpt.pt/documentation>

=cut

1;
