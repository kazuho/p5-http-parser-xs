package HTTP::Parser::XS;

use strict;
use warnings;

use base qw(Exporter);

our %EXPORT_TAGS = (
    'all' => [ qw/parse_http_request parse_http_response
                  HEADERS_NONE HEADERS_AS_HASHREF HEADERS_AS_ARRAYREF/ ],
);
our @EXPORT_OK = @{$EXPORT_TAGS{all}};
our @EXPORT = ();

# header format for parse_http_response()
use constant {
    HEADERS_NONE => 0,       # don't parse headers. It's fastest. if you want only special headers, also fastest.
    HEADERS_AS_HASHREF => 1,    # HTTP::Headers compatible HashRef, { header_name => "header_value" or ["val1", "val2"] }
    HEADERS_AS_ARRAYREF =>2,    # Ordered ArrayRef : [ name, value, name2, value2 ... ]
};

our $VERSION = '0.16';

our $BACKEND;

if (not __PACKAGE__->can('parse_http_response')) {
    $BACKEND = $ENV{PERL_HTTP_PARSER_XS} || ($ENV{PERL_ONLY} ? 'pp' : '');
    if ($BACKEND !~ /\b pp \b/xms) {
        eval {
            require XSLoader;
            XSLoader::load(__PACKAGE__, $VERSION);
            $BACKEND = 'xs';
        };
        die $@ if $@ && $BACKEND =~ /\bxs\b/;
    }
    if (not __PACKAGE__->can('parse_http_response')) {
        require HTTP::Parser::XS::PP;
        $BACKEND = 'pp';
    }
}

1;
__END__

=head1 NAME

HTTP::Parser::XS - a fast, primitive HTTP request parser

=head1 SYNOPSIS

  use HTTP::Parser::XS qw(parse_http_request);

  # for HTTP servers
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


  # for HTTP clients
  use HTTP::Parser::XS qw(parse_http_response HEADERS_AS_ARRAYREF);
  my %special_headers = (
    'content-length' => undef,
  );
  my($ret, $minor_version, $status, $message, $headers)
    = parse_http_response($response, HEADERS_AS_ARRAYREF, \%special_headers);

  if($ret == -1) }
    # response is incomplete
  }
  elsif($ret == -2) {
    # response is broken
  }
  else {
    # $ret is the length of the headers, starting the content body

    # the other values are the response messages. For example:
    # $status  = 200
    # $message = "OK"
    # $headers = [ 'content-type' => 'text/html', ... ]

    # and $special_headers{'content-length'} will be filled in
  }


=head1 DESCRIPTION

HTTP::Parser::XS is a fast, primitive HTTP request/response parser.

The request parser can be used either for writing a synchronous HTTP server or a event-driven server.

The response parser can be used for writing HTTP clients.

Note that even if this distribution name ends C<::XS>, B<pure Perl>
implementation is supported, so you can use this module on compiler-less
environments.

=head1 FUNCTIONS

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

Note that the semantics of PATH_INFO is somewhat different from Apache.  First, L<HTTP::Parser::XS> does not validate the variable; it does not raise an error even if PATH_INFO does not start with "/".  Second, the variable is conformant to RFC 3875 (and L<PSGI> / L<Plack>) in the fact that "//" and ".." appearing in PATH_INFO are preserved whereas Apache transcodes them.

=item parse_http_response($response_string, $header_format, \%special_headers)

Tries to parse given response string. I<$header_format> must be
C<HEADERS_AS_ARRAYREF>, C<HEADERS_AS_HASHREF>, or C<HEADERS_NONE>,
which are exportable constants.

The optional I<%special_headers> is for headers you specifically require.
You can set any HTTP response header names, which must be lower-cased,
and their default values, and then the values are filled in by
C<parse_http_response()>.
For example, if you want the C<Cointent-Length> field, set its name with
default values like C<< %h = ('content-length' => undef) >> and pass it as
I<%special_headers>. After parsing, C<$h{'content-length'}> is set
if the response has the C<Content-Length> field, otherwise it's not touched.

The return values are:

=over 8

=item C<$ret>

The parsering status, which is the same as C<parse_http_response()>. i.e.
the length of the response headers in bytes, C<-1> for incomplete headers,
or C<-2> for errors.

If the given response string is broken or imcomplete, C<parse_http_response()>
returns only this value.

=item C<$minor_version>

The minor version of the given response.
i.e. C<1> for HTTP/1.1, C<0> for HTTP/1.0.

=item C<$status>

The HTTP status of the given response. e.g. C<200> for success.

=item C<$message>

The HTTP status message. e.g. C<OK> for success.

=item C<$headers>

The HTTP headers for the given response. It is an ARRAY reference
if I<$header_format> is C<HEADERS_AS_ARRAYREF>, a HASH reference on
C<HEADERS_AS_HASHREF>, an C<undef> on C<HEADERS_NONE>.

The names of the headers are normalized to lower-cased.

=back

=back

=head1 LIMITATIONS

Both C<parse_http_request()> and C<parse_http_response()> in XS
implementation have some size limitations.

=head2 The number of headers

The number of headers is limited to C<128>. If it exceeds, both parsing
routines report parsing errors, i.e. return C<-1> for C<$ret>.

=head2 The size of header names

The size of header names is limited to C<1024>, but the parsers do not the
same action.

C<parse_http_request()> returns C<-1> if too-long header names exist.

C<parse_http_request()> simply ignores too-long header names.

=head1 COPYRIGHT

Copyright 2009- Kazuho Oku

=head1 AUTHOR

Kazuho Oku
gfx
mala
tokuhirom

=head1 THANKS TO

nothingmuch
charsbar

=head1 SEE ALSO

L<http://github.com/kazuho/picohttpparser>

L<HTTP::Parser>

L<HTTP::HeaderParser::XS>

L<Plack>

L<PSGI>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
