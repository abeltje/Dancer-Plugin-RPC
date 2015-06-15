package TestProject::SystemCalls;
use warnings;
use strict;

=head2 do_ping()

Returns true

=head3 XMLRPC system.ping

=for xmlrpc system.ping do_ping

=cut

sub do_ping {
    return \1;
}

=head2 do_version()

Returns the current version

=head3 XMLRPC system.version

=for xmlrpc system.version do_version

=cut

sub do_version {
    return {
        software_version => '1.0',
    };
}
1;
