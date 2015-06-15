package TestProject;
use Dancer ':syntax';
use Dancer::Plugin::RPC::XMLRPC;

# Register calls directly via POD
xmlrpc '/system' => {
    publish   => 'pod',
    arguments => ['TestProject::SystemCalls'],
};

xmlrpc '/api'    => {
    publish   => 'pod',
    arguments => ['TestProject::ApiCalls'],
};

# Register calls via YAML-config
xmlrpc '/admin' => {publish => 'config'};

true;
