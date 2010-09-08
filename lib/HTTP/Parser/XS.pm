package HTTP::Parser::XS;

use strict;
use warnings;

use base qw(Exporter);

our %EXPORT_TAGS = (
    'all' => [ qw/parse_http_request/ ],
);
our @EXPORT_OK = @{$EXPORT_TAGS{all}};
our @EXPORT = ();

our $VERSION = '0.09';

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

=head1 DESCRIPTION

HTTP::Parser::XS is a fast, primitive HTTP request parser that can be used either for writing a synchronous HTTP server or a event-driven server.

=head1 METHODS

=over 4

=item parse_http_request($request_string, \%env)

Tries to parse given request string, and if successful, inserts variables into %env.  For the name of the variables inserted, please refer to the PSGI specification.  The return values are:

=over 8

=item >=0

length of the request (request line and the request headers), in bytes

=item -1

given request is corrupt

=item -2

given request is incomplete

=back

=back

=head1 COPYRIGHT

Copyright 2009- Kazuho Oku

=head1 AUTHOR

Kazuho Oku

=head1 THANKS TO

nothingmuch
charsbar

=head1 SEE ALSO

L<HTTP::Parser>
L<HTTP::HeaderParser::XS>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
