#!perl -w
use strict;
use Test::More;
use HTTP::Parser::XS qw(:all);

my $res = "HTTP/1.0 200 OK\x0d\x0aFoo: épée\x0d\x0a\x0d\x0a";
utf8::upgrade($res);

my %env;

my ($ret, $minor_version, $status, $message, $headers) = HTTP::Parser::XS::parse_http_response($res, HEADERS_AS_HASHREF);

is(
    $headers->{'foo'},
    'épée',
    'upgraded string parses as expected',
) or diag explain [$ret, $minor_version, $status, $message, $headers];

done_testing;
