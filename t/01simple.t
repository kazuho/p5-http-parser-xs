use Test::More tests => 13;

use HTTP::Parser::XS qw(parse_http_request);

my $req;
my %env;

undef $@;
eval {
    parse_http_request("GET / HTTP/1.0\r\n\r\n", '');
};
ok($@, '"croak if second param is not a hashref');
undef $@;

$req = "GET /abc?x=%79 HTTP/1.0\r\n\r\n";
%env = ();
is(parse_http_request($req, \%env), length($req), 'simple get');
is_deeply(\%env, {
    PATH_INFO       => '/abc',
    QUERY_STRING    => 'x=%79',
    REQUEST_METHOD  => "GET",
    REQUEST_URI     => '/abc?x=%79',
    SCRIPT_NAME     => '',
    SERVER_PROTOCOL => 'HTTP/1.0',
}, 'result of GET /');

$req = <<"EOT";
POST /hoge HTTP/1.1\r
Content-Type: text/plain\r
Content-Length: 15\r
Host: example.com\r
User-Agent: hoge\r
\r
EOT
%env = ();
is(parse_http_request($req, \%env), length($req), 'POST');
is_deeply(\%env, {
    CONTENT_LENGTH  => 15,
    CONTENT_TYPE    => 'text/plain',
    HTTP_HOST       => 'example.com',
    HTTP_USER_AGENT => 'hoge',
    PATH_INFO       => '/hoge',
    REQUEST_METHOD  => "POST",
    REQUEST_URI     => '/hoge',
    QUERY_STRING    => '',
    SCRIPT_NAME     => '',
    SERVER_PROTOCOL => 'HTTP/1.1',
}, 'result of GET with headers');

$req = <<"EOT";
GET / HTTP/1.0\r
Foo: \r
Foo: \r
  abc\r
 de\r
Foo: fgh\r
\r
EOT
%env = ();
is(parse_http_request($req, \%env), length($req), 'multiline header');
is_deeply(\%env, {
    HTTP_FOO        => ',   abc de, fgh',
    PATH_INFO       => '/',
    QUERY_STRING    => '',
    REQUEST_METHOD  => 'GET',
    REQUEST_URI     => '/',
    SCRIPT_NAME     => '',
    SERVER_PROTOCOL => 'HTTP/1.0',
}, 'multiline');

$req = <<"EOT";
GET /a%20b HTTP/1.0\r
\r
EOT
%env = ();
is(parse_http_request($req, \%env), length($req), 'url-encoded');
is_deeply(\%env, {
    PATH_INFO      => '/a b',
    REQUEST_METHOD => 'GET',
    REQUEST_URI    => '/a%20b',
    QUERY_STRING   => '',
    SCRIPT_NAME     => '',
    SERVER_PROTOCOL => 'HTTP/1.0',
});

$req = <<"EOT";
GET /a%2zb HTTP/1.0\r
\r
EOT
%env = ();
is(parse_http_request($req, \%env), -1, 'invalid char in url-encoded path');
is_deeply(\%env, {});

$req = <<"EOT";
GET /a%2 HTTP/1.0\r
\r
EOT
%env = ();
is(parse_http_request($req, \%env), -1, 'partially url-encoded');
is_deeply(\%env, {});

# dumb HTTP client: https://github.com/miyagawa/Plack/issues/213
$req = <<"EOT";
GET /a/b#c HTTP/1.0\r
\r
EOT
%env = ();
is(parse_http_request($req, \%env), length($req), 'URI fragment');
is_deeply(\%env, {
    SCRIPT_NAME => '',
    PATH_INFO   => '/a/b',
    REQUEST_METHOD => 'GET',
    REQUEST_URI    => '/a/b#c',
    QUERY_STRING   => '',
    SCRIPT_NAME     => '',
    SERVER_PROTOCOL => 'HTTP/1.0',
});

$req = <<"EOT";
GET /a/b%23c HTTP/1.0\r
\r
EOT
%env = ();
is(parse_http_request($req, \%env), length($req), '%23 -> #');
is_deeply(\%env, {
    SCRIPT_NAME => '',
    PATH_INFO   => '/a/b#c',
    REQUEST_METHOD => 'GET',
    REQUEST_URI    => '/a/b%23c',
    QUERY_STRING   => '',
    SCRIPT_NAME     => '',
    SERVER_PROTOCOL => 'HTTP/1.0',
});

$req = <<"EOT";
GET /a/b?c=d#e HTTP/1.0\r
\r
EOT
%env = ();
is(parse_http_request($req, \%env), length($req), 'URI fragment after query string');
is_deeply(\%env, {
    SCRIPT_NAME => '',
    PATH_INFO   => '/a/b',
    REQUEST_METHOD => 'GET',
    REQUEST_URI    => '/a/b?c=d#e',
    QUERY_STRING   => 'c=d',
    SCRIPT_NAME     => '',
    SERVER_PROTOCOL => 'HTTP/1.0',
});
