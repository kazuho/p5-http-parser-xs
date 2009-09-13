use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'HTTP::Parser::XS',
    VERSION_FROM  => 'lib/HTTP/Parser/XS.pm',
    PREREQ_PM     => {},
    ABSTRACT_FROM => 'lib/HTTP/Parser/XS.pm',
    AUTHOR        => 'Kazuho Oku',
    LIBS          => [],
    DEFINE        => '',
    INC           => '-I.',
);
