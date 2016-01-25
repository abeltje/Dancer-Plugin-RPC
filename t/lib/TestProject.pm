package TestProject;
use Dancer ':syntax';
use Dancer::Plugin::RPC::JSONRPC;
use Dancer::Plugin::RPC::XMLRPC;

# Register calls directly via POD
xmlrpc '/system' => {
    publish   => 'pod',
    arguments => ['TestProject::SystemCalls'],
};

# Register calls directly via POD
xmlrpc '/api'    => {
    publish   => 'pod',
    arguments => ['TestProject::ApiCalls'],
};

# Register calls via YAML-config
xmlrpc '/config/system' => { publish => 'config' };
xmlrpc '/config/api'    => { publish => 'config' };

# Register calls directly via POD
jsonrpc '/jsonrpc/api' => {
    publish => 'pod',
    arguments => ['TestProject::ApiCalls']
};

# Register calls via YAML-config
jsonrpc '/jsonrpc/admin' => { publish => 'config' };

true;
