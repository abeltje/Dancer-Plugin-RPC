package Dancer::Plugin::RPC::XMLRPC;
use v5.10;
use Dancer ':syntax';
use Dancer::Plugin;

our $VERSION = '0.02';

no if $] >= 5.018, warnings => 'experimental::smartmatch';

use Params::Validate ':all';
use Pod::Simple::PullParser;
use RPC::XML::ParserFactory;

my %dispatch_builder_map = (
    pod    => \&build_dispatcher_from_pod,
    config => \&build_dispatcher_from_config,
);

register xmlrpc => sub {
    my($self, $endpoint, $arguments) = plugin_args(@_);

    my $publisher;
    given ($arguments->{publish}) {
        when (exists $dispatch_builder_map{$_}) {
            $publisher = $dispatch_builder_map{$_};
            $arguments->{arguments} = plugin_setting() if $_ eq 'config';
        }
        default {
            $publisher = $_;
        }
    }

    my $dispatcher = $publisher->($arguments->{arguments});

    my $handle_call = sub {
        if (request->method ne 'POST') {
            pass and return 0;
        }
        if (request->content_type ne 'text/xml') {
            pass and return 0;
        }

        debug("[handle_xmlrpc_call] Processing: ", request->body);
        local $RPC::XML::ENCODING = 'UTF-8';
        my $p = RPC::XML::ParserFactory->new();
        my $request = $p->parse(request->body);
        debug("[handle_xmlrpc_call] Parsed request: ", $request);

        my $method_name = $request->name;
        if (! exists $dispatcher->{$method_name}) {
            pass and return 0;
        }

        my @method_args = map $_->value, @{$request->args};
        my $handler = $dispatcher->{$method_name};

        my $response = $handler->($method_name, @method_args);

        return xmlrpc_response($response);
    };

    content_type 'text/xml';
    post $endpoint, $handle_call;
};

sub xmlrpc_response {
    my ($data) = @_;

    my $response;
    if (ref $data eq 'HASH' && exists $data->{faultCode}) {
        $response = RPC::XML::fault->new($data);
    }
    elsif (grep /^faultCode$/, @_) {
        $response = RPC::XML::fault->new({@_});
    }
    else {
        $response = RPC::XML::response->new(@_);
    }
    debug("[xmlrpc_response] ", $response->as_string);
    return $response->as_string;
}

sub build_dispatcher_from_pod {
    my ($pkgs) = @_;
    debug("[build_dispatcher_from_pod]");

    my $dispatch;
    for my $pkg (@$pkgs) {
        debug("[build_dispatcher_from_pod] $pkg");
        eval "require $pkg";
        error("Loading $pkg: $@") if $@;

        my $pkg_dispatch = parse_pod(
            package   => $pkg,
            labels    => ['xmlrpc'],
        );
        debug("[build_pkg_dispatcher] $pkg ", $pkg_dispatch);

        @{$dispatch}{keys %$pkg_dispatch} = @{$pkg_dispatch}{keys %$pkg_dispatch};
    }
    debug("[build_dispatcher] ", $dispatch);
    return $dispatch;
}

# =for $label $interface_name $code_name
sub parse_pod {
    my $args = validate(
        @_,
        {
            package => {
                type  => SCALAR,
                regex => qr/^.+$/,
            },
            labels    => {type => ARRAYREF},
        }
    );
    (my $pkg_as_file = "$args->{package}.pm") =~ s{::}{/}g;
    my $pkg_file = $INC{$pkg_as_file};
    debug("Checking for POD in $pkg_file for $args->{package} via $pkg_as_file");

    use autodie;
    open my $fh, '<', $pkg_file;

    my $p = Pod::Simple::PullParser->new();
    $p->accept_targets(@{ $args->{labels} });
    $p->set_source($fh);

    my $dispatch;
    while (my $token = $p->get_token) {
        next if not ($token->is_start && $token->is_tag('for'));

        my $label = $token->attr('target');

        my $ntoken = $p->get_token;
        while ($ntoken && ! $ntoken->can('text')) { $ntoken = $p->get_token; }
        last if !$ntoken;

        debug("=for-token $label => ", $ntoken->text);
        my ($if_name, $code_name) = split " ", $ntoken->text;
        debug("[build_dispatcher] $args->{package}\::$code_name => $if_name");

        $dispatch->{$if_name} = $args->{package}->can($code_name);
    }
    return $dispatch;
}

sub build_dispatcher_from_config {
    my ($config) = @_;
    debug("[build_dispatcher_from_config] ", $config);

    my @pkgs = keys %{$config->{package}};

    my $dispatch;
    for my $pkg (@pkgs) {
        eval "require $pkg";
        error("Loading $pkg: $@") if $@;

        my @rpc_methods = keys %{ $config->{package}{$pkg} };
        for my $rpc_method (@rpc_methods) {
            my $subname = $config->{package}{$pkg}{$rpc_method};
            debug("[bdfc] $rpc_method => $subname");
            $dispatch->{$rpc_method} = $pkg->can($subname);
        }
    }
    debug("[build_dispatcher_from_config]-> ", $dispatch);
    return $dispatch;
}

register_plugin();
true;

=head1 NAME

Dancer::Plugin::XMLRPC - XMLRPC Plugin for Dancer

=head2 SYNOPSIS

In the Controler-bit:

    use Dancer::Plugin::XMLRPC;
    xmlrpc '/admin' => {
        publish   => 'pod',
        arguments => ['MyProject::Admin']
    };

and in the Model-bit (B<MyProject::Admin>):

    package MyProject::Admin;

    =for xmlrpc rpc.abilities rpc_show_abilities
    
    =cut
    
    sub rpc_show_abilities {
        return {
            # datastructure
        };
    }
    1;

=head1 DESCRIPTION

This plugin lets one bind an endpoint to a set of modules with the new B<xmlrpc> keyword.

=head2 xmlrpc '/path/to/endpoint' => %publisher_arguments;

=head3 C<%publisher_arguments>

=over

=item publisher => <pod | config | \&code_ref>

The publiser key determines the way one connects the rpc-method name with the actual code.

=over

=item publisher => 'pod'

This way of publishing enables one to use a special POD directive C<=for xmlrpc>
to connect the rpc-method name to the actual code. The directive must be in the
same file as where the code resides.

    =for xmlrpc admin.someFunction rpc_admin_some_function

The POD-publisher needs the C<arguments> value to be an arrayref with package names in it.

=item publisher => 'config'

This way of publishing requires you to create a dispatch-table in the app's config YAML:

    Plugins:
        XMLRPC:
            package:
                'MyProject::Admin':
                    admin.someFunction rpc_admin_some_function
                'MyProject::User':
                    user.otherFunction rpc_user_other_function

The Config-publisher doesn't use the C<arguments> value of the C<%publisher_arguments> hash.

=item publisher => \&code_ref

This way of publishing requires you to write your own way of building the dispatch-table.
The code_ref you supply, gets the C<arguments> value of the C<%publisher_arguments> hash.

=back

=item arguments => <anything>

The value of this key depends on the publisher-method chosen.

=back

=head2 =for xmlrpc xmlrpc-method-name sub-name

This special POD-construct is used for coupling the xmlrpc-methodname to the
actual sub-name in the current package.

=head1 COPYRIGHT

(c) MMXV - Abe Timmerman <abeltje@cpan.org>

=cut
