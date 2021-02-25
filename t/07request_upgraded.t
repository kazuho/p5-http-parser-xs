#!perl -w
use strict;
use Test::More;
use HTTP::Parser::XS qw(:all);

my $req = "GET / HTTP/1.0\x0d\x0aHost: haha.com\x0d\x0aFoo: épée\x0d\x0a\x0d\x0a";
utf8::upgrade($req);

my %env;

HTTP::Parser::XS::parse_http_request($req, \%env);

is(
    $env{'HTTP_FOO'},
    'épée',
    'upgraded string parses as expected',
);

done_testing;
