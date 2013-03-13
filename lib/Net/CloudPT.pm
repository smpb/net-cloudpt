package Net::CloudPT;

use strict;
use warnings;

use URI;
use JSON;
use Net::OAuth; $Net::OAuth::PROTOCOL_VERSION = Net::OAuth::PROTOCOL_VERSION_1_0A;
use LWP::UserAgent;
use LWP::Protocol::https;
use Data::Random 'rand_chars';
use Carp qw/carp cluck/;

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

    $self->{target} ||= 'cloudpt'; # or 'sandbox'

    $self->{debug} ||= $ENV{DEBUG};

    return $self;
  }
  else
  {
    carp "ERROR: Please specify the 'key' and 'secret' parameters.";
  }

  # nok
  return;
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

  if ( $response->is_success )
  {
    $self->{errstr} = '';

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
    $self->{errstr} = $response->status_line;
    carp "ERROR: " . $self->{errstr};
  }

  # nok
  return;
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

    if ( $response->is_success )
    {
      $self->{errstr} = '';

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
      $self->{errstr} = $response->status_line;
      carp "ERROR: " . $self->{errstr};
    }
  }
  else
  {
    $self->{errstr} = "Authorization 'verifier' needed.";
    carp "ERROR: " . $self->{errstr};
  }

  # nok
  return;
}

=head2 metadata

Returns all the metadata available for a given file or folder (specified through its C<path>).

    $metadata = $cloud->metadata( path => '/Photos' );

=cut

sub metadata
{
  my $self = shift;
  my %args = @_;

  my $path = '';
  if ( defined $args{path} )
  {
    $path = $args{path};
    delete $args{path};
  }
  my $endpoint  = 'publicapi';
  my $options   = { %args };

  my $response = $self->_execute(
    command   => 'Metadata',
    endpoint  => $endpoint,
    path      => $path,
    target    => $self->{target},
    options   => $options,
  );

  return from_json $response;
}

=head2 metadata_share

Returns the metadata of a shared resource. Its share C<id> and C<name> are required.

    $data = $cloud->metada_share( share_id => 'a1bc7534-3786-40f1-b435-6fv90a00b2a6', name => 'Photo.jpg' );

=cut

sub metadata_share
{
  my $self = shift;
  my %args = @_;

  my $endpoint  = 'publicapi';

  my $response = $self->_execute(
    command   => 'MetadataShare',
    endpoint  => $endpoint,
    target    => $args{id},
    path      => $args{name},
  );

  return from_json $response;
}

=head2 list_links

Returns a list of all the public links created by the user.

    $data = $cloud->list_links;

=cut

sub list_links
{
  my $self = shift;
  my $endpoint = 'publicapi';

  my $response = $self->_execute(
    command   => 'ListLinks',
    endpoint  => $endpoint,
  );

  return from_json $response;
}

=head2 delete_link

Delete a public link of a file or folder. Its share C<id> is required.

    $response = $cloud->delete_link( id => 'a1bc7534-3786-40f1-b435-6fv90a00b2a6' );

=cut

sub delete_link
{
  my $self = shift;
  my %args = @_;

  my $endpoint  = 'publicapi';
  my $method    = 'POST';

  my $response = $self->_execute(
    command   => 'DeleteLink',
    endpoint  => $endpoint,
    method    => $method,
    content   => { shareid => $args{id} },
  );

  return from_json $response;
}

=head2 shares

Create a public link of a file or folder. Its C<path> is required.

    $response = $cloud->shares( path => '/Photos/logo.png' );

=cut

sub shares
{
  my $self = shift;
  my %args = @_;

  my $endpoint  = 'publicapi';
  my $method    = 'POST';

  my $response = $self->_execute(
    command   => 'Shares',
    endpoint  => $endpoint,
    method    => $method,
    target    => $self->{target},
    path      => $args{path},
  );

  return from_json $response;
}

=head2 share_folder

Share a folder with another user. The folder's C<path>, and a target C<email> are required.

    $response = $cloud->share_folder( path => '/Photos', email => 'friend@home.com' );

=cut

sub share_folder
{
  my $self = shift;
  my %args = @_;

  my $endpoint  = 'publicapi';
  my $method    = 'POST';

  my $response = $self->_execute(
    command   => 'ShareFolder',
    endpoint  => $endpoint,
    method    => $method,
    target    => $self->{target},
    path      => $args{path},
    content   => { to_email => $args{email} },
  );

  return from_json $response;
}

=head2 list_shared_folders

Returns a list of all the shared folders accessed by the user.

    $data = $cloud->list_shared_folders;

=cut

sub list_shared_folders
{
  my $self = shift;
  my $endpoint = 'publicapi';

  my $response = $self->_execute(
    command   => 'ListSharedFolders',
    endpoint  => $endpoint,
  );

  return from_json $response;
}

=head2 list

Returns metadata for a given file or folder (specified through its C<path>). Similar to the actual C<metadata> method, but with less items and more options.

    $metadata = $cloud->list( path => '/Photos' );

=cut

sub list
{
  my $self = shift;
  my %args = @_;

  my $path = '';
  if ( defined $args{path} )
  {
    $path = $args{path};
    delete $args{path};
  }
  my $endpoint  = 'publicapi';
  my $options   = { %args };

  my $response = $self->_execute(
    command   => 'List',
    endpoint  => $endpoint,
    path      => $path,
    target    => $self->{target},
    options   => $options,
  );

  return from_json $response;
}

=head2 error

Return the most recent error message. If the last API request was completed
successfully, this method will return an empty string.

=cut

sub error { shift->{errstr} }

=head1 INTERNAL API

=head2 _nonce

Generate a unique 'nonce' to be used on each request.

=cut

sub _nonce { join( '', rand_chars( size => 16, set => 'alphanumeric' )); }

=head2 _execute

Execute a particular API request to the service's protected resources.

=cut

sub _execute
{
  my $self = shift;
  my %args = @_;

  $args{method}   ||= 'GET';
  $args{endpoint} ||= 'publicapi'; # 'api-content'

  # build the request URI
  my @uri_bits = ( 'https://' . $args{endpoint} . '.cloudpt.pt/1' );
  push @uri_bits, $args{command};
  push @uri_bits, $args{target} if ( defined $args{target} );
  if ( defined $args{path} )
  {
    $args{path} =~ s/^\///g; # remove the leading slash
    push @uri_bits, $args{path}
  }

  my $uri = URI->new( join '/', @uri_bits );
  $uri->query_form($args{options}) if scalar keys %{$args{options}};

  my $request = Net::OAuth->request("protected resource")->new(
    consumer_key      => $self->{key},
    consumer_secret   => $self->{secret},
    request_url       => $uri->as_string,
    request_method    => $args{method},
    signature_method  => 'HMAC-SHA1',
    timestamp         => time,
    nonce             => $self->_nonce,
    token             => $self->{access_token},
    token_secret      => $self->{access_secret},
  );

  $request->sign;

  cluck "Executing '" . $args{method} . "' request to: '" . $uri->as_string . "'" if ( $self->{debug} );

  my $response;
  if ( $args{method} =~ /GET/i )
  {
    $response = $self->{ua}->get($request->to_url);
  }
  else
  {
    if ( defined $args{content} )
    {
      $response = $self->{ua}->post($request->to_url, Content_Type => 'form-data', Content => $args{content});
    }
    else
    {
      $response = $self->{ua}->post($request->to_url);
    }
  }

  if ( $response->is_success and $response->content ne '' )
  {
    $self->{errstr} = '';

    cluck "Response content: '" . $response->content . "'" if ( $self->{debug} );

    my $data;
    eval { $data = from_json($response->content) };

    if ($@) # it's not JSON; could be file content
    {
      return $response->content;
    }

    $data->{http_response_code} = $response->code() if ( ref $data eq 'HASH' );
    return to_json($data);
  }
  else
  {
    return to_json { http_response_code => $response->code };
  }
}

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

