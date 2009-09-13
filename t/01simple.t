use Test::More tests => 4;

use HTTP::Parser::XS qw(parse_http_request);

my %env;

is(parse_http_request("GET / HTTP/1.0\r\n\r\n", \%env), 0, 'GET /');
is_deeply(\%env, {
    REQUEST_METHOD  => "GET",
    SCRIPT_NAME     => '',
    PATH_INFO       => '/',
    SERVER_PROTOCOL => 'HTTP/1.0',
}, 'result of GET /');

is(parse_http_request("GET /hoge HTTP/1.1\r\nHost: example.com\r\nCookie: a=b\r\n\r\n", \%env), 2, 'GET with headers');
is_deeply(\%env, {
    REQUEST_METHOD  => "GET",
    SCRIPT_NAME     => '',
    PATH_INFO       => '/hoge',
    SERVER_PROTOCOL => 'HTTP/1.1',
    HTTP_HOST       => 'example.com',
    HTTP_COOKIE     => 'a=b',
}, 'result of GET with headers');
