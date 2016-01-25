#! perl -w
use strict;
use lib 't/lib';

use Test::More;

use Dancer qw/:syntax !pass/;
use Dancer::Plugin::RPC::JSONRPC;

use Dancer::Test;

{ # default publish => 'pod' ; Batch-mode
    jsonrpc '/endpoint' => {
        arguments => ['TestProject::SystemCalls'],
    };

    route_exists([POST => '/endpoint'], "/endpoint registered");

    my $response = dancer_response(
        POST => '/endpoint',
        {
            headers => [
                'Content-Type' => 'application/json',
            ],
            body => to_json([
                {
                    jsonrpc => '2.0',
                    method  => 'system.ping',
                    id      => 42,
                },
                {
                    jsonrpc => '2.0',
                    method  => 'system.version',
                    id      => 43,
                }
            ]),
        }
    );

    my @results = map $_->{result}, @{from_json($response->{content})};
    is_deeply(
        \@results,
        [
            'true',
            {software_version => '1.0'},
        ],
        "system.ping"
    );
}

{ # publish is code that returns the dispatch-table
    jsonrpc '/endpoint2' => {
        publish => sub {
            eval { require TestProject::SystemCalls; };
            error("Cannot load: $@") if $@;
            return {
                'code.ping' => \&TestProject::SystemCalls::do_ping,
            };
        },
        callback => sub { return {success => 1}; },
    };

    route_exists([POST => '/endpoint2'], "/endpoint2 registered");

    my $response = dancer_response(
        POST => '/endpoint2',
        {
            headers => [
                'Content-Type' => 'application/json',
            ],
            body => to_json(
                {
                    jsonrpc => '2.0',
                    method  => 'code.ping',
                    id      => 42,
                }
            ),
        }
    );

    is_deeply(
        from_json($response->{content})->{result},
        'true',
        "code.ping"
    );
}

{ # callback fails
    jsonrpc '/endpoint_fail' => {
        publish => sub {
            eval { require TestProject::SystemCalls; };
            error("Cannot load: $@") if $@;
            return {
                'fail.ping' => \&TestProject::SystemCalls::do_ping,
            };
        },
        callback => sub {
            return {
                success       => 0,
                error_code    => -500,
                error_message => "Force callback error",
            };
        },
    };

    route_exists([POST => '/endpoint_fail'], "/endpoint_fail registered");

    my $response = dancer_response(
        POST => '/endpoint_fail',
        {
            headers => [
                'Content-Type' => 'application/json',
            ],
            body => to_json(
                {
                    jsonrpc => '2.0',
                    method  => 'fail.ping',
                    id      => 42,
                }
            ),
        }
    );

    is_deeply(
        from_json($response->{content})->{error},
        {code => -500, message =>"Force callback error"},
        "fail.ping"
    );
}

{ # rpc-call fails
    jsonrpc '/endpoint_error' => {
        publish => sub {
            return {
                'fail.error' => sub { die "Example error code\n" },
            };
        },
    };

    route_exists([POST => '/endpoint_error'], "/endpoint_error registered");

    my $response = dancer_response(
        POST => '/endpoint_error',
        {
            headers => [
                'Content-Type' => 'application/json',
            ],
            body => to_json(
                {
                    jsonrpc => '2.0',
                    method  => 'fail.error',
                    id      => 42,
                }
            ),
        }
    );

    is_deeply(
        from_json($response->{content})->{error},
        {code => 500, message =>"Example error code\n"},
        "fail.error"
    );
}

done_testing();
