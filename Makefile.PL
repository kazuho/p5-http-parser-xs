use inc::Module::Install;
use Module::Install::TestTarget;
use Module::Install::ReadmeMarkdownFromPod;

name 'HTTP-Parser-XS';
all_from('lib/HTTP/Parser/XS.pm');
author 'Kazuho Oku';

test_requires 'Test::More' => 0.96;

test_target test_pp => (
    env => { PERL_ONLY => 1 },
	(alias => 'test')
);

WriteAll;

eval {
    require Pod::Text;
    my $p = Pod::Text->new;
    $p->output_fh(do {
        open my $fh, '>', "README.$$" or die $!;
        $fh;
    });
    $p->parse_file('lib/HTTP/Parser/XS.pm');
    undef $p;
    rename "README.$$", 'README'
        or die $!;
};

print "Warning: no README, please install newest Pod::Text and rerun Makefile.PL\n"
    unless -e 'README';
