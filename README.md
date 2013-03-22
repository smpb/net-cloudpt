# NAME

Net::CloudPT - A CloudPT interface

# VERSION

Version 0.01

# SYNOPSYS

This module is a Perl interface to the API for the Portuguese cloud storage
service CloudPT. You can learn more about it at [http://www.cloudpt.pt](http://www.cloudpt.pt).

Quick start:

    use Net::CloudPT;

    my $cloud = Net::CloudPT->new( key => 'KEY', secret => 'SECRET' );
    $cloud->login;

    # the user manually authorizes the app, retrieving the verifier PIN...

    $cloud->authorize( verifier => $pin );

    my $response = $cloud->share( path => '/Photos/logo.png' );
    my $data = $cloud->get_file( path => '/Photos/logo.png' );

The particular details regarding the API can be found at [https://cloudpt.pt/documentation](https://cloudpt.pt/documentation)

# API

## `new`

Create a new `Net::CloudPT` object. The `key` and `secret` parameters are required.

## `login`

Perform the initial login operation, identifying the client on the service.

If the handshake is successful, a request token/secret is obtained which allows
an authorization URL to be returned. This URL must be opened by the user to
explicitly authorize access to the service's account.

Furthermore, CloudPT then either redirects the user back to the callback URL
(if defined in `$self->{callback_url}`), or openly provides a PIN number
that will be required to verify that the user's authorization is valid.

## `authorize`

This method exchanges the request token/secret, obtained after a successful
login, with an access token/secret that is needed for subsequent accesses to
the service's API.

The `verifier` PIN parameter is required.

## `account_info`

Shows information about the user.

    $data = $cloud->account_info;

## `metadata`

Returns all the metadata available for a given file or folder (specified
through its `path`).

    $metadata = $cloud->metadata( path => '/Photos' );

## `metadata_share`

Returns the metadata of a shared resource. Its share `id` and `name` are
required.

    $data = $cloud->metada_share(
      share_id => 'a1bc7534-3786-40f1-b435-6fv90a00b2a6', name => 'logo.png'
    );

## `list_links`

Returns a list of all the public links created by the user.

    $data = $cloud->list_links;

## `delete_link`

Delete a public link of a file or folder. Its share `id` is required.

    $response = $cloud->delete_link( id => 'a1bc7534-3786-40f1-b435-6fv90a00b2a6' );

## `share`

Create a public link of a file or folder. Its `path` is required.

    $response = $cloud->share( path => '/Photos/logo.png' );

## `share_folder`

Share a folder with another user. The folder's `path`, and a target `email`
are required.

    $response = $cloud->share_folder(
      path => '/Photos', email => 'friend@home.com'
    );

## `list_shared_folders`

Returns a list of all the shared folders accessed by the user.

    $data = $cloud->list_shared_folders;

## `list`

Returns metadata for a given file or folder (specified through its `path`).
Similar to the actual `metadata` method, but with less items and more options.

    $metadata = $cloud->list( path => '/Photos' );

## `thumbnail`

Return the thumbnail (in binary format) of the file specified in the `path`.

    $content = $cloud->thumbnail( path => '/Photos/logo.png' );

## `search`

Search the `path` for a file, or folder, that matches the given `query`.

    $content = $cloud->search( path => '/Photos' query => 'logo.png' );

## `revisions`

Obtain information of the most recent version on the file in the `path`.

    $content = $cloud->search( path => '/Photos/logo.png' );

## `restore`

Restore a specific `revision` of the file in the `path`.

    $response = $cloud->restore(
      path     => '/Photos/logo.png',
      revision => '384186e2-31e9-11e2-927c-e0db5501ca40'
    );

## `media`

Return a direct link for the file in the `path`. If it's a video/audio file, a
streaming link is returned per the `protocol` parameter.

    $response = $cloud->media( path => '/Music/song.mp3', protocol => 'rtsp' );

## `delta`

List the current changes available for syncing.

    $data = $cloud->delta;

## `put_file`

Upload a file to CloudPT.
You can choose to `overwrite` it (this being either `true` or `false`), if
it already exists, as well as choose to overwrite a `parent_rev` of the file.

    $response = $cloud->put_file( file => 'logo2.png', path => '/Photos' );

## `get_file`

Download a file from CloudPT. A specific `rev` can be requested.

    $data = $cloud->get_file( path => '/Photos/logo2.png' );

## `copy`

From a file in `from_path`, create a copy in `to_path`.
Alternatively, instead of `from_path`, a copy from a file reference can be
done with `from_copy_ref`. The reference is generated from a previous call to
`copy_ref`.

    $response = $cloud->copy(
      from_path => '/Photos/logo2.png', to_path => '/Music/cover.png'
    );

## `copy_ref`

Creates, and returns, a copy reference to the file in `path`.
This can be used to copy that file to another user's CloudPT.

    $response = $cloud->copy_ref( path => '/Music/cover.png' );

## `move`

Take a file in `from_path`, and move it into `to_path`.

    $response = $cloud->move(
      from_path => '/Photos/logo2.png', to_path => '/Music/cover.png'
    );

## `create_folder`

Create a folder in `path`.

    $response = $cloud->create_folder( path => '/Music/Rock' );

## `delete`

Delete a file in `path`.

    $response = $cloud->delete( path => '/Music/cover.png' );

## `undelete`

Undelete a file, or folder, previously removed.

    $response = $cloud->undelete( path => '/Music/cover.png' );

## `error`

Return the most recent error message. If the last API request was completed
successfully, this method will return an empty string.

# INTERNAL API

## `_nonce`

Generate a unique 'nonce' to be used on each request.

## `_execute`

Execute a particular API request to the service's protected resources.

# AUTHOR

Sérgio Bernardino, `<code@sergiobernardino.net>`

# COPYRIGHT & LICENSE

Copyright 2013 Sérgio Bernardino.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.
