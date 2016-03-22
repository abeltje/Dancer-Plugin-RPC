#! perl -w
use strict;
use lib 't/lib';

use Test::More;

use Dancer qw/:syntax !pass/;
use Dancer::Plugin::RPC::JSONRPC;
use Dancer::RPCPlugin::CallbackResult;
use Dancer::RPCPlugin::DispatchItem;

use Dancer::Test;

{ # default publish => 'pod' ; Batch-mode
    set(plugins => {
        'RPC::JSONRPC' => {
            '/endpoint' => {
                'TestProject::SystemCalls' => {
                    'system.ping' => 'do_ping',
                    'system.version' => 'do_version',
                },
            },
        }
    });
    jsonrpc '/endpoint' => { };

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
            from_json(to_json(\1)),
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
                'code.ping' => dispatch_item(
                    code => \&TestProject::SystemCalls::do_ping,
                    package => 'TestProject::SystemCalls',
                ),
            };
        },
        callback => sub { return callback_success() },
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
        from_json(to_json(\1)),
        "code.ping"
    );
}

{ # callback fails
    jsonrpc '/endpoint_fail' => {
        publish => sub {
            eval { require TestProject::SystemCalls; };
            error("Cannot load: $@") if $@;
            return {
                'fail.ping' => dispatch_item(
                    code => \&TestProject::SystemCalls::do_ping,
                    package => 'TestProject::SystemCalls',
                ),
            };
        },
        callback => sub {
            return callback_fail(
                error_code    => -500,
                error_message => "Force callback error",
            );
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

{ # callback dies
    jsonrpc '/endpoint_fail2' => {
        publish => sub {
            eval { require TestProject::SystemCalls; };
            error("Cannot load: $@") if $@;
            return {
                'fail.ping' => dispatch_item(
                    code => \&TestProject::SystemCalls::do_ping,
                    package => 'TestProject::SystemCalls',
                ),
            };
        },
        callback => sub {
            die "terrible death\n";
        },
    };

    route_exists([POST => '/endpoint_fail2'], "/endpoint_fail registered");

    my $response = dancer_response(
        POST => '/endpoint_fail2',
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
        {code => 500, message =>"terrible death\n"},
        "fail.ping"
    );
}


{ # rpc-call fails
    jsonrpc '/endpoint_error' => {
        publish => sub {
            return {
                'fail.error' => dispatch_item(
                    code => sub { die "Example error code\n" },
                    package => __PACKAGE__,
                ),
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
