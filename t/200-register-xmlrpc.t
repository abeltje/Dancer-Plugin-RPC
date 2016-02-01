#! perl -w
use strict;
use lib 't/lib';

use Test::More;

use Dancer qw/:syntax !pass/;
use Dancer::Plugin::RPC::XMLRPC;
use Dancer::RPCPlugin::CallbackResult;
use Dancer::RPCPlugin::DispatchItem;

use Dancer::Test;

use RPC::XML;
use RPC::XML::ParserFactory;
my $p = RPC::XML::ParserFactory->new();

{ # default publish (config)
    set(plugins => {
        'RPC::XMLRPC' => {
            '/endpoint' => {
                'TestProject::SystemCalls' => {
                    'system.ping' => 'do_ping',
                    'system.version' => 'do_version',
                },
            },
        }
    });
    xmlrpc '/endpoint' => { };

    route_exists([POST => '/endpoint'], "/endpoint registered");

    my $response = dancer_response(
        POST => '/endpoint',
        {
            headers => [
                'Content-Type' => 'text/xml',
            ],
            body => RPC::XML::request->new(
                'system.ping',
            )->as_string,
        }
    );

    my $result = $p->parse($response->{content})->value;

    is_deeply(
        $result->value,
        1,
        "system.ping"
    );
}

{ # publish is code that returns the dispatch-table
    xmlrpc '/endpoint2' => {
        publish => sub {
            eval { require TestProject::SystemCalls; };
            error("Cannot load: $@") if $@;
            return {
                'code.ping' => dispatch_item(
                    code => TestProject::SystemCalls->can('do_ping'),
                    package => 'TestProject::SystemCalls',
                ),
            };
        },
        callback => sub { return callback_success(); },
    };

    route_exists([POST => '/endpoint2'], "/endpoint2 registered");

    my $response = dancer_response(
        POST => '/endpoint2',
        {
            headers => [
                'Content-Type' => 'text/xml',
            ],
            body => RPC::XML::request->new(
                'code.ping',
            )->as_string,
        }
    );

    # diag(explain($response));
    my $result = $p->parse($response->{content})->value;
    is_deeply(
        $result->value,
        1,
        "code.ping"
    );
}

{ # callback fails
    xmlrpc '/endpoint_fail' => {
        publish => sub {
            eval { require TestProject::SystemCalls; };
            error("Cannot load: $@") if $@;
            return {
                'fail.ping' => dispatch_item(
                    code => TestProject::SystemCalls->can('do_ping'),
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
                'Content-Type' => 'text/xml',
            ],
            body => RPC::XML::request->new('fail.ping')->as_string,
        }
    );

    # diag(explain($response));
    my $result = $p->parse($response->{content})->value;
    is_deeply(
        $result->value,
        {faultCode => -500, faultString =>"Force callback error"},
        "fail.ping"
    );
}

{ # rpc-call fails
    xmlrpc '/endpoint_error' => {
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
                'Content-Type' => 'text/xml',
            ],
            body => RPC::XML::request->new('fail.error')->as_string,
        }
    );

    my $result = $p->parse($response->{content})->value;
    is_deeply(
        $result->value,
        {faultCode => 500, faultString =>"Example error code\n"},
        "fail.error"
    );
}

done_testing();
