#! perl -w
use strict;
use lib 't/lib';

use Test::More;

use TestProject;
use Dancer::Test;

route_exists([POST => '/system'], "/system exsits");
route_exists([POST => '/api'],    "/api exists");
route_exists([POST => '/admin'],  "/admin exists");

route_doesnt_exist([GET => '/'], "no GET /");

done_testing();
