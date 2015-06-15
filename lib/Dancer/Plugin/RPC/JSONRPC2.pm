package Dancer::Plugin::RPC::JSONRPC2;
use warnings;
use strict;

our $VERSION = '0.10';

use Dancer ':syntax';
use Dancer::Plugin;

=head1 NAME

Dancer::Plugin::JSONRPC2 - Dancer Plugin to register jsonrpc2 methods.

=head1 SYNOPSIS

    use Dancer ':syntax';
    use Dancer::Plugin::JSONRPC2;

    get '/' => sub { return "Hello, world!" };

    # define a dispatch table for all calls on this endpoint:
    jsonrpc2 '/jsonrpc' => {
        'rpc.version => sub { return {version => 42} },
        'create_stuff' => sub {
            my ($params) = @_;
        },
    };

=head1 DESCRIPTION

This plugin helps you register handlers for JSONRPC2 method calls. It handles
the requests and responses. The only things you'll need to provide are:

=over

=item endpoint: The 'path' part of the url for which the method calls are valid.

=item dispatch_table: key-value pairs: C<method-name> => C<code-ref>

=back

=cut

register jsonrpc2 => sub {
    my ($self, $endpoint, $request_handlers) = plugin_args(@_);

    my $jsonrpc2_route = sub {
        # Check for: Content-Type: application/json
        if (request->content_type ne 'application/json') {
            pass and return 0;
        }
        my @requests;
        my $unjson = from_json(request->body, {utf8 => 1});
        if (ref($unjson) ne 'ARRAY') {
            @requests = ($unjson);
        }
        else {
            @requests = @$unjson;
        }
        # loop over actual requests
        my @responses;
        for my $request (@requests) {
            my $call = $request->{method};
            if (!exists $request_handlers->{$call}) {
                my $error = {
                    jsonrpc => '2.0',
                    code => -32601,
                    message => 'Method not found',
                    exists $request->{id}
                        ? (id => $request->{id})
                        : (),
                };
                push @responses, $error;
            }

            my $result = eval {
                $request_handlers->{$call}->($request->{params});
            };
            if (my $error = $@) {
                push @responses, {
                    jsonrpc => '2.0',
                    error => {
                        code => 500,
                        msg => $error,
                    },
                    exists $request->{id}
                        ? (id => $request->{id})
                        : (),
                };
            }
            else {
                push @responses, {
                    jsonrpc => '2.0',
                    result => $result,
                    exists $request->{id}
                        ? (id => $request->{id})
                        : (),
                };
            }
        }

        # create response
        my $response;
        if (@responses == 1) {
            $response = to_json($responses[0]);
        }
        else {
            $response = to_json(\@responses);
        }

        return $response;
    };

    # register route to endpoint
    post $endpoint, $jsonrpc2_route;
};

register_plugin;
1;

=head1 LICENSE & STUFF

(c) MMXIII - Abe Timmerman <abeltje@cpan.org>.

=cut
