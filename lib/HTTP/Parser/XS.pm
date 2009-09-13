package HTTP::Parser::XS;

use strict;
use warnings;

use Exporter qw(import);

our %EXPORT_TAGS = (
    'all' => [ qw/parse_http_request/ ],
);
our @EXPORT_OK = @{$EXPORT_TAGS{all}};
our @EXPORT = ();

our $VERSION = '0.01';

require XSLoader;
XSLoader::load('HTTP::Parser::XS', $VERSION);

1;
__END__

=head1 NAME

HTTP::Parser::XS - a fast, primitive HTTP request parser

=cut
