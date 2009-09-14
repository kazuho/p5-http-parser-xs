use Test::More tests => 6;

use HTTP::Parser::XS qw(parse_http_request);

my $req;
my %env;

$req = "GET / HTTP/1.0\r\n\r\n";
%env = ();
is(parse_http_request($req, \%env), length($req), 'GET /');
is_deeply(\%env, {
    REQUEST_METHOD  => "GET",
    SCRIPT_NAME     => '',
    PATH_INFO       => '/',
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
    REQUEST_METHOD  => "POST",
    SCRIPT_NAME     => '',
    PATH_INFO       => '/hoge',
    SERVER_PROTOCOL => 'HTTP/1.1',
    CONTENT_TYPE    => 'text/plain',
    CONTENT_LENGTH  => 15,
    HTTP_HOST       => 'example.com',
    HTTP_USER_AGENT => 'hoge',
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
    REQUEST_METHOD  => 'GET',
    SCRIPT_NAME     => '',
    PATH_INFO       => '/',
    SERVER_PROTOCOL => 'HTTP/1.0',
    HTTP_FOO        => ',   abc de, fgh',
}, 'multiline');
