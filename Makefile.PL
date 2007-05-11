use inc::Module::Install;

name           'MRO-Compat';
all_from       'lib/MRO/Compat.pm';

build_requires 'Test::More'    => '0.47';

auto_install;
WriteAll;
