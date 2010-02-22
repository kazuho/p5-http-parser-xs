use ExtUtils::MakeMaker;
use Pod::Text;

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

my $p = Pod::Text->new;
$p->output_fh(do {
    open my $fh, '>', 'README' or die $!;
    $fh;
});
$p->parse_file('lib/HTTP/Parser/XS.pm');
