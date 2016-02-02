#! perl -w
use strict;
use v5.10.1;

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'Dancer::Plugin::RPC',
    VERSION_FROM  => 'lib/Dancer/Plugin/RPC.pm',
    ABSTRACT_FROM => 'lib/Dancer/Plugin/RPC.pm',
    AUTHOR        => 'Abe Timmerman <abeltje@cpan.org>',

    PREREQ_PM => {
        'overload'         => '1.07',
        'Plack'            => '1.003',
        'Dancer'           => '1.32',
        'Params::Validate' => '1.0',
        'RPC::XML'         => '1.0',
        'JSON'             => '2.0',
        },

    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 6.56,
    },

    BUILD_REQUIRES => {
        'Test::More'  => '0.88', # done_testing()
        'Test::Fatal' => '0.010',
    },

    MIN_PERL_VERSION => '5.010001',

    META_ADD => {
        'meta-spec' => {
            version    => 2,
        },
        'resources' => {
            homepage   => "https://github.com/abeltje/Dancer-Plugin-RPC",
            repository => {
                type   => "git",
                url    => "git://github.com/abeltje/Dancer-Plugin-RPC.git",
                web    => "https://github.com/abeltje/Dancer-Plugin-RPC",
            },
#            x_IRC      => "irc://irc.perl.org/#amsterdam.pm",
        },
    },
);
