use inc::Module::Install;
use Module::Install::TestTarget;
use Module::Install::ReadmeFromPod;

name 'HTTP-Parser-XS';
all_from('lib/HTTP/Parser/XS.pm');
readme_from('lib/HTTP/Parser/XS.pm');
author 'Kazuho Oku';
repository 'https://github.com/kazuho/p5-http-parser-xs';

test_requires 'Test::More' => 0.96;

test_target test_pp => (
    env => { PERL_ONLY => 1 },
	(alias => 'test')
);

WriteAll;
