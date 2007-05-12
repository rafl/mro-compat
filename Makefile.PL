use inc::Module::Install;

name           'MRO-Compat';
all_from       'lib/MRO/Compat.pm';

build_requires 'Test::More'    => '0.47';

if($] < 5.009_005) {
    feature 'XS Speedups', 'Class::C3::XS' => '0.04';
    requires       'Class::C3'     => '0.18';
}

auto_install;
WriteAll;
