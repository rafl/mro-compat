package MRO::Compat;
use strict;
use warnings;
require 5.006_000;

# Keep this < 1.00, so people can tell the fake
#  mro.pm from the real one
our $VERSION = '0.01_01';

BEGIN {
    # Alias our private functions over to
    # the mro:: namespace and load
    # Class::C3 if Perl < 5.9.5
    if($] < 5.009_005) {
        require Class::C3;
        *mro::import            = \&__import;
        *mro::get_linear_isa    = \&__get_linear_isa;
        *mro::set_mro           = \&__set_mro;
        *mro::get_mro           = \&__get_mro;
        *mro::get_isarev        = \&__get_isarev;
        *mro::is_universal      = \&__is_universal;
        *mro::method_changed_in = \&__method_changed_in;
        *mro::invalidate_all_method_caches
                                = \&__invalidate_all_method_caches;
        $mro::VERSION = $VERSION;
        $INC{'mro.pm'} = 'Faked by MRO::Compat';
    }

    # Provide no-op Class::C3::.*initialize() funcs for 5.9.5+
    else {
        no warnings 'redefine';
        *Class::C3::initialize = sub { 1 };
        *Class::C3::reinitialize = sub { 1 };
        *Class::C3::uninitialize = sub { 1 };
    }
}

=head1 NAME

MRO::Compat - mro::* interface compatibility for Perls < 5.9.5

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

This module provides those interfaces for
earlier versions of Perl (back to 5.6.0 anyways).

It is a harmless no-op to use this module on 5.9.5+.  If
you're writing a piece of software that would like to use
the parts of 5.9.5+'s mro:: interfaces that are supported
here, and you want compatibility with older Perls, this
is the module for you.

This module never exports any functions.  All calls must
be fully qualified with the C<mro::> prefix.

=head1 VERSION 0.01_01

This is the first dev release of this new module, and on top of that,
the Perl 5.9.5 it seeks to provide compatibility with isn't even
out yet.  Consider it not fully stabilized for the time being.
These interfaces are not necessarily nailed down yet.

=head1 Functions

=head2 mro::get_linear_isa($classname[, $type])

Returns an arrayref which is the linearized MRO of the given class.
Uses whichever MRO is currently in effect for that class by default,
or the given MRO (either C<c3> or C<dfs> if specified as C<$type>).

The linearized MRO of a class is a single ordered list of all of the
classes that would be visited in the process of resolving a method
on the given class, starting with itself.  It does not include any
duplicate entries.

Note that C<UNIVERSAL> (and any members of C<UNIVERSAL>'s MRO) are not
part of the MRO of a class, even though all classes implicitly inherit
methods from C<UNIVERSAL> and its parents.

=cut

sub __get_linear_isa_dfs {
    no strict 'refs';

    my $classname = shift;

    my @lin = ($classname);
    my %stored;
    foreach my $parent (@{"$classname\::ISA"}) {
        my $plin = __get_linear_isa_dfs($parent);
        foreach (@$plin) {
            next if exists $stored{$_};
            push(@lin, $_);
            $stored{$_} = 1;
        }
    }
    return \@lin;
}

sub __get_linear_isa {
    my ($classname, $type) = @_;
    die "mro::get_mro requires a classname" if !$classname;

    $type ||= __get_mro($classname);
    if($type eq 'dfs') {
        return __get_linear_isa_dfs($classname);
    }
    elsif($type eq 'c3') {
        return [Class::C3::calculateMRO($classname)];
    }
    die "type argument must be 'dfs' or 'c3'";
}

=head2 mro::import

This allows the C<use mro 'dfs'> and
C<use mro 'c3'> syntaxes, providing you
L<use MRO::Compat> first.  Please see the
L</USING C3> section for additional details.

=cut

sub __import {
    if($_[1]) {
        goto &Class::C3::import if $_[1] eq 'c3';
        __set_mro(scalar(caller), $_[1]);
    }
}

=head2 mro::set_mro($classname, $type)

Sets the mro of C<$classname> to one of the types
C<dfs> or C<c3>.  Please see the L</USING C3>
section for additional details.

=cut

sub __set_mro {
    my ($classname, $type) = @_;
    if(!$classname || !$type) {
        die q{Usage: mro::set_mro($classname, $type)};
    }
    if($type eq 'c3') {
        eval "package $classname; use Class::C3";
        die $@ if $@;
    }
    if($type ne 'dfs') {
        die q{Invalid mro type "$type"};
    }

    # In the dfs case, check whether we need to undo C3
    if(defined $Class::C3::MRO{$classname}) {
        Class::C3::_remove_method_dispatch_table($classname);
    }
    delete $Class::C3::MRO{$classname};

    return;
}

=head2 mro::get_mro($classname)

Returns the MRO of the given class (either C<c3> or C<dfs>).

It considers any Class::C3-using class to have C3 MRO
even before L<Class::C3::initialize()> is called.

=cut

sub __get_mro {
    my $classname = shift;
    die "mro::get_mro requires a classname" if !$classname;
    return 'c3' if exists $Class::C3::MRO{$classname};
    return 'dfs';
}

=head2 mro::get_isarev($classname)

Returns an array of classes who are subclasses of the
given classname.  In other words, classes who we exists,
however indirectly, in the @ISA inheritancy hierarchy of.

This is much slower on pre-5.9.5 Perls with MRO::Compat
than it is on 5.9.5+, as it has to search the entire
package namespace.

=cut

sub __get_all_pkgs_with_isas {
    no strict 'refs';
    no warnings 'recursion';

    my @retval;

    my $search = shift;
    my $pfx;
    my $isa;
    if($search) {
        $isa = \@{"$search\::ISA"};
        $pfx = "$search\::";
    }
    else {
        $search = 'main';
        $isa = \@main::ISA;
        $pfx = '';
    }

    push(@retval, $search) if scalar(@$isa);

    foreach my $cand (keys %{"$search\::"}) {
        if($cand =~ /::$/) {
            $cand =~ s/::$//;
            next if $cand eq $search; # skip self-reference (main?)
            push(@retval, @{__get_all_pkgs_with_isas($pfx . $cand)});
        }
    }

    return \@retval;
}

sub __get_isarev_recurse {
    no strict 'refs';

    my ($class, $all_isas, $level) = @_;

    die "Recursive inheritance detected" if $level > 100;

    my %retval;

    foreach my $cand (@$all_isas) {
        my $found_me;
        foreach (@{"$cand\::ISA"}) {
            if($_ eq $class) {
                $found_me = 1;
                last;
            }
        }
        if($found_me) {
            $retval{$cand} = 1;
            map { $retval{$_} = 1 }
                @{__get_isarev_recurse($cand, $all_isas, $level+1)};
        }
    }
    return [keys %retval];
}

sub __get_isarev {
    my $classname = shift;
    die "mro::get_isarev requires a classname" if !$classname;

    @{__get_isarev_recurse($classname, __get_all_pkgs_with_isas(), 0)};
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

    my $lin = __get_linear_isa('UNIVERSAL');
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

=head1 USING C3

While this module makes the 5.9.5+ syntaxes
C<use mro 'c3'> and C<mro::set_mro("Foo", 'c3')> available
on older Perls, it does so merely by passing off the work
to L<Class::C3>.

It does not remove the need for you to call
L<Class::C3>'s C<initialize()>, C<reinitialize()>, and/or
C<uninitialize()> at the appropriate times
as documented in the L<Class::C3> docs.

Because L<MRO::Compat> has L<Class::C3> as a pre-requisite,
and requires it at C<use> time, you can blindly call
those functions in code that uses L<MRO::Compat>.
Under 5.9.5+ with L<MRO::Compat>, your calls to those
functions will become a no-op and everything will work fine.

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
