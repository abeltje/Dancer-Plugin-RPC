#! perl -w
use strict;
use lib 't/lib';

use Test::More;
use Dancer::Test;

use Dancer::RPCPlugin::DispatchFromConfig;

{
    pass("test");
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
}

done_testing();
