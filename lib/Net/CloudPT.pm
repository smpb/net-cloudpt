package Net::CloudPT;

use strict;
use warnings;

use Carp qw/carp cluck/;
use JSON;
use Net::OAuth; $Net::OAuth::PROTOCOL_VERSION = Net::OAuth::PROTOCOL_VERSION_1_0A;
use LWP::UserAgent;
use LWP::Protocol::https;
use Data::Random 'rand_chars';

=head1 NAME

Net::CloudPT - A CloudPT interface

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSYS

This module is a Perl interface to the API for the Portuguese cloud storage
service CloudPT. You can learn more about it at L<http://www.cloudpt.pt>.

Quick start:

    use Net::CloudPT;

    my $cloud = Net::CloudPT->new( key => 'KEY', secret => 'SECRET' );
    $cloud->login;

    # authorize the app, retrieving the verifier PIN...

    $cloud->authorize( verifier => $pin );

The particular details regarding the API can be found at L<https://cloudpt.pt/documentation>

=head1 API

=head2 new

Create a new C<Net::CloudPT> object. The C<key> and C<secret> parameters are required.

=cut

sub new
{
  my $class = shift;

  my $self = bless { @_ }, $class;

  if ( $self->{key} and $self->{secret} )
  {
    $self->{ua} ||= LWP::UserAgent->new;

    $self->{callback_url}   ||= 'oob',
    $self->{request_url}    ||= 'https://cloudpt.pt/oauth/request_token',
    $self->{authorize_url}  ||= 'https://cloudpt.pt/oauth/authorize',
    $self->{access_url}     ||= 'https://cloudpt.pt/oauth/access_token',

    $self->{debug} ||= $ENV{DEBUG};

    return $self;
  }
  else
  {
    carp "ERROR: Please specify the 'key' and 'secret' parameters.";
  }
}

=head2 login

Perform the initial login operation, identifying the client on the service.

If the handshake is successful, a request token/secret is obtained which allows
an authorization URL to be returned. This URL must be opened by the user to
explicitly authorize access to the service's account.

Furthermore, CloudPT then either redirects the user back to the callback URL
(if defined in C<$self-E<gt>{callback_url}>), or openly provides a PIN number
that will be required to verify that the user's authorization is valid.

=cut

sub login
{
  my $self = shift;

  my $request = Net::OAuth->request('request token')->new(
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

  $request->sign;

  my $response = $self->{ua}->post($request->to_url);

  if ($response->is_success)
  {
    my $response = Net::OAuth->response('request token')->from_post_body($response->content);
    $self->{request_token}  = $response->token;
    $self->{request_secret} = $response->token_secret;

    cluck "Request Token: '"   . $self->{request_token}   . "'" if ( $self->{debug} );
    cluck "Request Secret: '"  . $self->{request_secret}  . "'" if ( $self->{debug} );

    my $authorize = $self->{authorize_url} . '?oauth_token=' . $self->{request_token};
    $authorize .= '&oauth_callback=' . $self->{callback_url}
      if ( defined $self->{callback_url} and $self->{callback_url} ne 'oob' );

    cluck "Authorization URL: '$authorize'" if ( $self->{debug} );

    # ok
    return $authorize;
  }
  else
  {
    carp "ERROR: " . $response->status_line;
  }

  # nok
  return 0;
}

=head2 authorize

This method exchanges the request token/secret, obtained after a successful
login, with an access token/secret that is needed for subsequent accesses to
the service's API.

The C<verifier> PIN parameter is required.

=cut

sub authorize
{
  my $self = shift;
  my %args = @_;

  if ( $args{verifier} )
  {
    my $request = Net::OAuth->request('access token')->new(
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

    $request->sign;

    my $response = $self->{ua}->post($request->to_url);

    if ($response->is_success)
    {
      my $response = Net::OAuth->response('access token')->from_post_body($response->content);
      $self->{access_token}  = $response->token;
      $self->{access_secret} = $response->token_secret;

      cluck "Access Token: '"   . $self->{access_token} . "'"   if ( $self->{debug} );
      cluck "Access Secret: '"  . $self->{access_secret} . "'"  if ( $self->{debug} );

      # ok
      return 1;
    }
    else
    {
      carp "ERROR: " . $response->status_line;
    }
  }
  else
  {
    carp "ERROR: Authorization 'verifier' needed.";
  }

  # nok
  return 0;
}

=head1 INTERNAL API

=head2 _nonce

Generate a unique 'nonce' to be used on each request.

=cut

sub _nonce { join( '', rand_chars( size => 16, set => 'alphanumeric' )); }

=head1 AUTHOR

Sérgio Bernardino, C<< <code@sergiobernardino.net> >>

=head1 COPYRIGHT & LICENSE

Copyright 2013 Sérgio Bernardino.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;

