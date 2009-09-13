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

=head1 SYNOPSIS

  use HTTP::Parser::XS qw(parse_http_request);
  
  my $ret = parse_http_request(
      "GET / HTTP/1.0\r\nHost: ...\r\n\r\n",
      \%env,
  );
  if ($ret == -2) {
      # request is incomplete
      ...
  } elsif ($ret == -1) {
      # request is broken
      ...
  } else {
      # $ret includes the size of the request, %env now contains a PSGI
      # request, if it is a POST / PUT request, read request content by
      # yourself
      ...
  }

=cut
