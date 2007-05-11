package MRO::Compat;
use strict;
use warnings;

our $VERSION = '0.01';

# Is Class::C3 installed locally?
our $C3_INSTALLED;

BEGIN {
    # Don't do anything if 5.9.5+
    if($] < 5.009_005) {
        # Find out if we have Class::C3 at all
        eval { require Class::C3 };
        $C3_INSTALLED = 1 if !$@;

        # Alias our private functions over to
        # the mro:: namespace
        *mro::import            = \&__import;
        *mro::get_linear_isa    = \&__get_linear_isa;
        *mro::set_mro           = \&__set_mro;
        *mro::get_mro           = \&__get_mro;
        *mro::get_isarev        = \&__get_isarev;
        *mro::is_universal      = \&__is_universal;
        *mro::method_changed_in = \&__method_changed_in;
        *mro::invalidate_all_method_caches
                                = \&__invalidate_all_method_caches;
    }
}

=head1 NAME

MRO::Compat - Partial mro::* interface compatibility for Perls < 5.9.5

=head1 SYNOPSIS

   package FooClass; use base qw/X Y Z/;
   package X;        use base qw/ZZZ/;
   package Y;        use base qw/ZZZ/;
   package Z;        use base qw/ZZZ/;

   package main;
   use MRO::Compat;
   my $linear = mro::get_linear_isa('FooClass');
   print join(q{, }, @$linear);

   # Prints: "FooClass, X, ZZZ, Y, Z"

=head1 DESCRIPTION

The "mro" namespace provides several utilities for dealing
with method resolution order and method caching in general
in Perl 5.9.5 and higher.

This module provides a subset of those interfaces for
earlier versions of Perl.  It is a harmless no-op to use
it on 5.9.5+.  If you're writing a piece of software
that would like to use the parts of 5.9.5+'s mro::
interfaces that are supported here, and you want
compatibility with older Perls, this is the module
for you.

This module never exports any functions.  All calls must
be fully qualified with the C<mro::> prefix.

=head1 Functions

=head2 mro::get_linear_isa($classname[, $type])

Returns an arrayref which is the linearized MRO of the given class.
Uses whichever MRO is currently in effect for that class by default,
or the given MRO (either C<c3> or C<dfs> if specified as C<$type>).

The linearized MRO of a class is a single ordered list of all of the
classes that would be visited in the process of resolving a method
on the given class, starting with itself.  It does not include any
duplicate entries.

On pre-5.9.5 Perls with MRO::Compat, explicitly asking for the C<c3>
MRO of a class will die if L<Class::C3> is not installed.  If
L<Class::C3> is installed, it will detect C3 classes and return the
correct C3 MRO unless explicitly asked to return the C<dfs> MRO.

Note that C<UNIVERSAL> (and any members of C<UNIVERSAL>'s MRO) are not
part of the MRO of a class, even though all classes implicitly inherit
methods from C<UNIVERSAL> and its parents.

=cut

sub __get_linear_isa {
}

=head2 mro::import

Not supported, and hence 5.9.5's "use mro 'foo'" is also not supported.
These will die if used on pre-5.9.5 Perls.

=cut

sub __import {
    die q{The "use mro 'foo'" is only supported on Perl 5.9.5+};
}

=head2 mro::set_mro($classname, $type)

Not supported, will die if used on pre-5.9.5 Perls.

=cut

sub __set_mro {
    die q{mro::set_mro() is only supported on Perl 5.9.5+};
}

=head2 mro::get_mro($classname)

Returns the MRO of the given class (either C<c3> or C<dfs>).

=cut

sub __get_mro {
    my $classname = shift
    die "mro::get_mro requires a classname" if !$classname;
    if($C3_INSTALLED && exists $Class::C3::MRO{$classname}
       && $Class::C3::_initialized) {
        return 'c3';
    }
    return 'dfs';
}

=head2 mro::get_isarev($classname)

Not supported, will die if used on pre-5.9.5 Perls.

=cut

sub __get_isarev {
    die "mro::get_isarev() is only supported on Perl 5.9.5+";
}

=head2 mro::is_universal($classname)

Returns a boolean status indicating whether or not
the given classname is either C<UNIVERSAL> itself,
or one of C<UNIVERSAL>'s parents by C<@ISA> inheritance.

Any class for which this function returns true is
"universal" in the sense that all classes potentially
inherit methods from it.

=cut

sub __is_universal {
    my $classname = shift;
    die "mro::is_universal requires a classname" if !$classname;

    my $lin = __get_linear_isa($classname);
    foreach (@$lin) {
        return 1 if $classname eq $_;
    }

    return 0;
}

=head2 mro::invalidate_all_method_caches

Increments C<PL_sub_generation>, which invalidates method
caching in all packages.

=cut

sub __invalidate_all_method_caches {
    # Super secret mystery code :)
    @fedcba98::ISA = @fedcba98::ISA;
    return;
}

=head2 mro::method_changed_in($classname)

Invalidates the method cache of any classes dependent on the
given class.  In L<MRO::Compat> on pre-5.9.5 Perls, this is
an alias for C<mro::invalidate_all_method_caches> above, as
pre-5.9.5 Perls have no other way to do this.  It will still
enforce the requirement that you pass it a classname, for
compatibility.

=cut

sub __method_changed_in {
    my $classname = shift;
    die "mro::method_changed_in requires a classname" if !$classname;

    __invalidate_all_method_caches();
}

=head1 SEE ALSO

L<Class::C3>

L<mro>

=head1 AUTHOR

Brandon L. Black, E<lt>blblack@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2007 Brandon L. Black E<lt>blblack@gmail.comE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

1;
