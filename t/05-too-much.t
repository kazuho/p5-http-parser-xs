#!perl -w
use strict;
use Test::More;
use HTTP::Parser::XS qw(:all);

plan skip_all => 'PP has no static limitations'
    if $HTTP::Parser::XS::BACKEND eq 'pp';

my $MAX_HEADER_LEN = 1024;
my $MAX_HEADERS    = 128;

my $crlf = "\015\012";

note 'request parser';
# on success
my $name = 'x' x $MAX_HEADER_LEN; # OK
my $request = "GET / HTTP/1.1" . $crlf
            . "$name: 42" . $crlf
            . $crlf;

my $env = {};
my $ret = parse_http_request($request, $env);
cmp_ok $ret, '>', 0, 'parsing status (success)';
is $env->{REQUEST_METHOD}, 'GET';
is $env->{'HTTP_' . uc $name}, 42, 'very long name';

# on fail
$name = 'x' x ($MAX_HEADER_LEN + 1);
$request = "GET / HTTP/1.1" . $crlf
          . "$name: 42" . $crlf
          . $crlf;

$env = {};
$ret = parse_http_request($request, $env);
cmp_ok $ret, '==', -1, 'parsing status (fail)';
is $env->{REQUEST_METHOD}, undef;
is $env->{'HTTP_' . uc $name}, undef, 'too long name';

# too many headers

$request = "GET / HTTP/1.1" . $crlf
          . join($crlf, map { "X$_: $_" } 0 .. $MAX_HEADERS) . $crlf
          . $crlf;

$env = {};
$ret = parse_http_request($request, $env);
is $ret, -1, 'too many headers';

note 'response parser';
# on success
$name = 'x' x $MAX_HEADER_LEN;
my $response = 'HTTP/1.1 200 OK' . $crlf
             . "$name: 42" . $crlf
             . $crlf;
($ret, my $minor_version, my $status, my $message, my $headers)
    = parse_http_response($response, HEADERS_AS_HASHREF);

cmp_ok $ret, '>', 0, 'parsing status (success)';
is $minor_version, 1;
is $status, 200;
is $message, 'OK';
is $headers->{$name}, 42, 'very long name';

# on fail
$name = 'x' x ($MAX_HEADER_LEN + 1);
$response = 'HTTP/1.1 200 OK' . $crlf
             . "$name: 42" . $crlf
             . "foo: bar" . $crlf
             . $crlf;
($ret, $minor_version, $status, $message, $headers)
    = parse_http_response($response, HEADERS_AS_HASHREF);

cmp_ok $ret, '>', -1, 'parsing status (fail)';
is_deeply $headers, { foo => 'bar' }, 'too long name is ignored'
    or diag(explain($headers));

# too many headers
$response = 'HTTP/1.1 200 OK' . $crlf
            . join($crlf, map { "X$_: $_" } 0 .. $MAX_HEADERS) . $crlf
            . "foo: bar" . $crlf
            . $crlf;
($ret) = parse_http_response($response, HEADERS_AS_HASHREF);
is $ret, -1, 'too many headers (fail)';


done_testing;

