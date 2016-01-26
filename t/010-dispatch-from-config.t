#! perl -w
use strict;
use lib 't/lib';

use Test::More;
use Test::Exception;
use Dancer::Test;

use Dancer::RPCPlugin::DispatchFromConfig;

{
    my $dispatch = dispatch_table_from_config(
        key      => 'xmlrpc',
        endpoint => '/xmlrpc',
        config   => {
            '/xmlrpc' => {
                'TestProject::SystemCalls' => {
                    'system.ping'    => 'do_ping',
                    'system.version' => 'do_version',
                }
            }
        }
    );
    is_deeply(
        $dispatch,
        {
            'system.ping'    => \&TestProject::SystemCalls::do_ping,
            'system.version' => \&TestProject::SystemCalls::do_version,
        },
        "Dispatch from YAML-config"
    );

    throws_ok(
        sub {
            dispatch_table_from_config(
                key      => 'xmlrpc',
                endpoint => '/xmlrpc',
                config   => {
                    '/xmlrpc' => {
                        'TestProject::SystemCalls' => {
                            'system.nonexistent' => 'nonexistent',
                        }
                    }
                },
            );
        },
        qr/Handler not found for system.nonexistent: TestProject::SystemCalls::nonexistent doesn't seem to exist/,
        "Setting a non-existent dispatch target throws an exception"
    );
}

done_testing();
