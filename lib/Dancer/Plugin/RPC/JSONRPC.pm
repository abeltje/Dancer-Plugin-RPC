package Dancer::Plugin::RPC::JSONRPC;
use v5.10;
use Dancer ':syntax';
use Dancer::Plugin;

our $VERSION = '0.10';

no if $] >= 5.018, warnings => 'experimental::smartmatch';

use Dancer::RPCPlugin::CallbackResult;
use Dancer::RPCPlugin::DispatchFromConfig;
use Dancer::RPCPlugin::DispatchFromPod;
use Dancer::RPCPlugin::DispatchItem;

my %dispatch_builder_map = (
    pod    => \&build_dispatcher_from_pod,
    config => \&build_dispatcher_from_config,
);

register jsonrpc => sub {
    my ($self, $endpoint, $arguments) = plugin_args(@_);

    my $publisher;
    given ($arguments->{publish} // 'config') {
        when (exists $dispatch_builder_map{$_}) {
            $publisher = $dispatch_builder_map{$_};
            $arguments->{arguments} = plugin_setting() if $_ eq 'config';
        }
        default {
            $publisher = $_;
        }
    }

    my $code_wrapper = $arguments->{code_wrapper} // sub {
        my $code = shift;
        my $pkg  = shift;
        $code->(@_);
    };
    my $callback = $arguments->{callback};
    my $dispatcher = $publisher->($arguments->{arguments}, $endpoint);

    my $handle_call = sub {
        if (request->content_type ne 'application/json') {
            pass();
        }

        my @requests = unjson(request->body);

        my @responses;
        for my $request (@requests) {
            my $method_name = $request->{method};
            debug("[handle_jsonrpc_call] $method_name ", $request);

            if (!exists $dispatcher->{$method_name}) {
                push @responses, jsonrpc_error_response(
                    -32601,
                    "Method '$method_name' not found",
                    $request->{id}
                );
                next;
            }

            my Dancer::RPCPlugin::CallbackResult $continue = $callback
                ? $callback->(request(), $method_name)
                : callback_success();

            if (!$continue->success) {
                push @responses, jsonrpc_error_response(
                    $continue->error_code,
                    $continue->error_message,
                    $request->{id}
                );
                next;
            }

            my @method_args = $request->{params};
            my Dancer::RPCPlugin::DispatchItem $di = $dispatcher->{$method_name};
            my $handler = $di->code;
            my $package = $di->package;

            my $result = eval {
                $code_wrapper->($handler, $package, $method_name, @method_args);
            };

            debug("[handeled_jsonrpc_call] ", $result);
            if (my $error = $@) {
                push @responses, jsonrpc_error_response(
                    500,
                    $error,
                    $request->{id}
                );
                next;
            }
            push @responses, {
                jsonrpc => '2.0',
                result => $result,
                exists $request->{id}
                    ? (id => $request->{id})
                    : (),
            };
        }

        # create response
        my $response;
        if (@responses == 1) {
            $response = to_json($responses[0]);
        }
        else {
            $response = to_json(\@responses);
        }

        content_type 'application/json';
        return $response;
    };

    post $endpoint, $handle_call;
};

sub unjson {
    my ($body) = @_;

    my @requests;
    my $unjson = from_json($body, {utf8 => 1});
    if (ref($unjson) ne 'ARRAY') {
        @requests = ($unjson);
    }
    else {
        @requests = @$unjson;
    }
    return @requests;
}

sub jsonrpc_error_response {
    my ($code, $message, $id) = @_;
    return {
        jsonrpc => '2.0',
        error => {
            code    => $code,
            message => $message,
        },
        defined $id ? (id => $id) : (),
    };
}

sub build_dispatcher_from_pod {
    my ($pkgs) = @_;
    debug("[build_dispatcher_from_pod]");

    return dispatch_table_from_pod(
        packages => $pkgs,
        label    => 'xmlrpc',
    );
}

sub build_dispatcher_from_config {
    my ($config, $endpoint) = @_;
    debug("[build_dispatcher_from_config] $endpoint");

    return dispatch_table_from_config(
        key      => 'jsonrpc',
        config   => $config,
        endpoint => $endpoint,
    );
}
register_plugin;
1;

=head1 NAME

Dancer::Plugin::RPC::JSONRPC - Dancer Plugin to register jsonrpc2 methods.

=head1 SYNOPSIS

In the Controler-bit:

    use Dancer::Plugin::RPC::JSONRPC;
    jsonrpc '/endpoint' => {
        publish   => 'pod',
        arguments => ['MyProject::Admin']
    };

and in the Model-bit (B<MyProject::Admin>):

    package MyProject::Admin;
    
    =for jsonrpc rpc.abilities rpc_show_abilities
    
    =cut
    
    sub rpc_show_abilities {
        return {
            # datastructure
        };
    }
    1;


=head1 DESCRIPTION

This plugin lets one bind an endpoint to a set of modules with the new B<jsonrpc> keyword.

=head2 jsonrpc '/endpoint' => \%publisher_arguments;

=head3 C<\%publisher_arguments>

=over

=item callback => $coderef [optional]

The callback will be called just before the actual rpc-code is called from the
dispatch table. The arguments are positional: (full_request, method_name).

    my $continue = $callback ? $callback->(request(), $method_name) : 1;

The callback should return a HashRef:

=over 8

=item on_success

The HashRef should have 1 key:

  - success => 1

=item on_failure

The HashRef should have 3 keys:

  - success       => 0
  - error_code    => <numeric_code>
  - error_message => <error message>

=back

=item code_wrapper => $coderef [optional]

The codewrapper will be called with these positional arguments:

=over 8

=item 1. $call_coderef

=item 2. $method_name

=item 3. @arguments

=back

The default code_wrapper-sub is:

    sub {
        my $code = shift;
        $code->(@_);
    };

=item publisher => <pod | config | \&code_ref>

The publiser key determines the way one connects the rpc-method name with the actual code.

=over

=item publisher => 'pod'

This way of publishing enables one to use a special POD directive C<=for jsonrpc>
to connect the rpc-method name to the actual code. The directive must be in the
same file as where the code resides.

    =for jsonrpc admin.someFunction rpc_admin_some_function_name

The POD-publisher needs the C<arguments> value to be an arrayref with package names in it.

=item publisher => 'config'

This way of publishing requires you to create a dispatch-table in the app's config YAML:

    plugins:
        "RPC::JSONRPC":
            '/endpoint':
                'MyProject::Admin':
                    admin.someFunction: rpc_admin_some_function_name
                'MyProject::User':
                    user.otherFunction: rpc_user_other_function_name

The Config-publisher doesn't use the C<arguments> value of the C<%publisher_arguments> hash.

=item publisher => \&code_ref

This way of publishing requires you to write your own way of building the dispatch-table.
The code_ref you supply, gets the C<arguments> value of the C<%publisher_arguments> hash.

A dispatch-table looks like:

    return {
        'admin.someFuncion' => dispatch_item(
            package => 'MyProject::Admin',
            code    => MyProject::Admin->can('rpc_admin_some_function_name'),
        ),
        'user.otherFunction' => dispatch_item(
            package => 'MyProject::User',
            code    => MyProject::User->can('rpc_user_other_function_name'),
        ),
    }

=back

=item arguments => <anything>

The value of this key depends on the publisher-method chosen.

=back

=head2 =for jsonrpc jsonrpc-method-name sub-name

This special POD-construct is used for coupling the jsonrpc-methodname to the
actual sub-name in the current package.

=head1 INTERNAL

=head2 unjson

Deserializes the string as Perl-datastructure.

=head2 jsonrpc_error_response

Returns a jsonrpc error response as a hashref.

=head2 build_dispatcher_from_config

Creates a (partial) dispatch table from data passed from the (YAML)-config file.

=head2 build_dispatcher_from_pod

Creates a (partial) dispatch table from data provided in POD.

=head1 COPYRIGHT

(c) MMXIII-MMXVI - Abe Timmerman <abeltje@cpan.org>.

=cut
