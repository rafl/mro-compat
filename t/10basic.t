
use strict;
use warnings;

use Test::More tests => 2;

BEGIN {
    use_ok('MRO::Compat');
}

{
    package AAA; our @ISA = qw//;
    package BBB; our @ISA = qw/AAA/;
    package CCC; our @ISA = qw/AAA/;
    package DDD; our @ISA = qw/AAA/;
    package EEE; our @ISA = qw/BBB CCC DDD/;
    package FFF; our @ISA = qw/EEE DDD/;
    package GGG; our @ISA = qw/FFF/;
}

is_deeply(
  mro::get_linear_isa('GGG'),
  [ 'GGG', 'FFF', 'EEE', 'BBB', 'AAA', 'CCC', 'DDD' ]
);
