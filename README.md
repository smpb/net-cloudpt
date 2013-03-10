# Net::CloudPT - A CloudPT interface

This module is a Perl interface to the API for the Portuguese cloud storage service CloudPT. You can learn more about it at <http://www.cloudpt.pt/>.

Quick start:


    use Net::CloudPT;

    my $cloud = Net::CloudPT->new( key => 'KEY', secret => 'SECRET' );
    $cloud->login;

    # authorize the app, retrieving the verifier PIN...

    $cloud->auth( verifier => $pin );


The particular details regarding the API can be found at <https://cloudpt.pt/documentation/>


