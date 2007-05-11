use inc::Module::Install;

name           '';
all_from       'lib/mro.pm';

build_requires 'Test::More'    => '0.47';

if($] > 5.009_004) {
    warn "*** There is no good reason to install this module on Perl version 5.9.5 or higher ***";
    # XXX can I prevent M::I from installing mro.pm in this case?
}

auto_install;
WriteAll;
