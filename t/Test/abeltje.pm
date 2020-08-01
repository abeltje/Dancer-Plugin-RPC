package t::Test::abeltje;
use v5.10.1;
use warnings;
use strict;

our $VERSION = '1.00';

use parent 'Test::Builder::Module';

use Test::Builder::Module;
use Test::More;
use Test::Fatal;
use Test::Warnings;

our @EXPORT = (
    @Test::More::EXPORT,
    @Test::Fatal::EXPORT,
    @Test::Warnings::EXPORT
);

sub import_extra {
    warnings->import();
    strict->import();

    require feature;
    feature->import( ':5.10' );

    require lib;
    lib->import('t/lib');
}

1;

=head1 NAME

t::Test::abeltje - Helper Test module that imports useful stuf.

=head1 SYNOPSIS

    #! perl -I.
    use t::Test::abeltje;

    # Don't forget -I. on the shebang line
    # this is where you have your Fav. test-routines.

=head1 DESCRIPTION

Mostly nicked from other modules (like L<Modern::Perl>)...

This gives you L<Test::More>, L<Test::Fatal>, L<Test::Warnings> and also imports
for you: L<strict>, L<warnings>, the L<feature> with the C<:5.10> tag and L<lib>
with the C<t/lib> path.

=head1 COPYRIGHT

(c) MMXX - Abe Timmerman <abeltje@cpan.org>

=cut
