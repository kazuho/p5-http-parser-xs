use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'HTTP::Parser::XS',
    VERSION_FROM  => 'lib/HTTP/Parser/XS.pm',
    PREREQ_PM     => {
	'Test::More' => 0,
    },
    ABSTRACT_FROM => 'lib/HTTP/Parser/XS.pm',
    AUTHOR        => 'Kazuho Oku',
    LIBS          => [],
    DEFINE        => '',
    INC           => '-I.',
);

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
