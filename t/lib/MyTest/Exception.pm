package MyTest::Exception;
use Moose;

use overload '""' => 'as_string';

has error => (is => 'ro', isa => 'Str');

sub as_string { $_[0]->error }

use namespace::autoclean;
__PACKAGE__->meta->make_immutable();
1;
