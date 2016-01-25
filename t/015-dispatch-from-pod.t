#! perl -w
use strict;
use lib 't/lib';

use Test::More;
use Dancer::Test;

use Dancer::RPCPlugin::DispatchFromPod;

{
    pass("test");
    my $dispatch = dispatch_table_from_pod(
        label    => 'jsonrpc',
        packages => [qw/
            TestProject::ApiCalls
        /],
    );
    is_deeply(
        $dispatch,
        {
            'api.uppercase' => \&TestProject::ApiCalls::do_uppercase,
        },
        "Dispatch table from POD"
    );
}

done_testing();

