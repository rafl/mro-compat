package mro;
use strict;
use warnings;

# mro.pm versions >= 1.00 reserved for the Perl core
our $VERSION = '0.01';

our $C3_INSTALLED;
BEGIN {
    eval { require Class::C3 };
    if(!$@) {
        $C3_INSTALLED = 1;
    }
}

sub import {
    die q{The "use mro 'foo'" syntax is only supported on Perl 5.9.5+}
        if $_[1];
}

=head1 NAME

mro - Method Resolution Order

=head1 SYNOPSIS

   package FooClass; use base qw/X Y Z/;
   package X;        use base qw/ZZZ/;
   package Y;        use base qw/ZZZ/;
   package Z;        use base qw/ZZZ/;

   package main;
   use mro;
   my $linear = mro::get_linear_isa('FooClass');
   print join(q{, }, @$linear) . "\n";

   # Prints: "FooClass, X, ZZZ, Y, Z"

=head1 DESCRIPTION

The "mro" namespace provides several utilities for dealing
with method resolution order and method caching in general.

It never exports any functions.  All calls must be fully
qualified with the C<mro::> prefix.

=head1 IMPORTANT INFORMATION

This module is only for use on Perls earlier than 5.9.5.
Perl version 5.9.5 and higher includes its own superior
implementation, with a version number greater than 1.00.

This CPAN implementation supports a small subset of the
features of the 5.9.5+ version, to make it easier for
some classes of modules to depend on these features and
be compatible with older Perls.

=head1 Functions

=head2 mro::get_linear_isa($classname[, $type])

Returns an arrayref which is the linearized MRO of the given class.
Uses whichever MRO is currently in effect for that class by default,
or the given MRO (either C<c3> or C<dfs> if specified as C<$type>).

The linearized MRO of a class is a single ordered list of all of the
classes that would be visited in the process of resolving a method
on the given class, starting with itself.  It does not include any
duplicate entries.

Explicitly asking for the C<c3> MRO of a class will die if
L<Class::C3> is not installed.  If L<Class::C3> is installed, it will
detect C3 classes and return the correct C3 MRO unless explicitly
asked to return the C<dfs> MRO.

Note that C<UNIVERSAL> (and any members of C<UNIVERSAL>'s MRO) are not
part of the MRO of a class, even though all classes implicitly inherit
methods from C<UNIVERSAL> and its parents.

=head2 mro::set_mro($classname, $type)

Not supported in this version, will die if used.

=head2 mro::get_mro($classname)

Returns the MRO of the given class (either C<c3> or C<dfs>).

=head2 mro::get_isarev($classname)

Not supported in this version, will die if used.

=head2 mro::is_universal($classname)

Returns a boolean status indicating whether or not
the given classname is either C<UNIVERSAL> itself,
or one of C<UNIVERSAL>'s parents by C<@ISA> inheritance.

Any class for which this function returns true is
"universal" in the sense that all classes potentially
inherit methods from it.

=head2 mro::invalidate_all_method_caches()

Increments C<PL_sub_generation>, which invalidates method
caching in all packages.

=head2 mro::method_changed_in($classname)

Invalidates the method cache of any classes dependent on the
given class.  In this version, this is an alias for
C<mro::invalidate_all_method_caches> above, as pre-5.9.5
Perls have no other way to do this.  It will still enforce
the requirement that you pass it a classname, for
compatibility with 5.9.5.

=head1 SEE ALSO

L<Class::C3>

=head1 AUTHOR

Brandon L. Black, E<lt>blblack@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2007 Brandon L. Black E<lt>blblack@gmail.comE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

1;
