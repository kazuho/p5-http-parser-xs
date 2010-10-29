use strict;
use warnings;
use Test::More;
use HTTP::Parser::XS qw/:all/;

my $tests = <<'__HEADERS';
HTTP/1.0 200 OK

----------
{
 '_content' => '',
 '_protocol' => 'HTTP/1.0',
 '_headers' => {},
 '_rc' => 200,
 '_msg' => 'OK'
}
----------
HTTP/1.0 200 OK
Content-Type: text/html

hogehoge
----------
{
 '_content' => "hogehoge\n",
 '_protocol' => 'HTTP/1.0',
 '_headers' => { "content-type" => "text/html"},
 '_rc' => 200,
 '_msg' => 'OK'
}
----------
HTTP/1.0 200 OK
Content-Type: text/html
X-Test: 1
X-Test: 2

hogehoge
----------
{
 '_content' => "hogehoge\n",
 '_protocol' => 'HTTP/1.0',
 '_headers' => { "content-type" => "text/html", "x-test" => [1,2]},
 '_rc' => 200,
 '_msg' => 'OK'
}
----------
HTTP/1.0 200 OK
Content-Type: text/html
X-Test: 1
 X-Test: 2

hogehoge
----------
{
 '_content' => "hogehoge\n",
 '_protocol' => 'HTTP/1.0',
 '_headers' => { "content-type" => "text/html", "x-test" => "1\n X-Test: 2"},
 '_rc' => 200,
 '_msg' => 'OK'
}
----------
HTTP/1.0 200 OK
Content-Type: text/html

----------
{
 '_content' => "",
 '_protocol' => 'HTTP/1.0',
 '_headers' => { "content-type" => "text/html"},
 '_rc' => 200,
 '_msg' => 'OK'
}
----------
HTTP/1.1 200 OK
Content-Type: text/html

----------
{
 '_content' => "",
 '_protocol' => 'HTTP/1.1',
 '_headers' => { "content-type" => "text/html"},
 '_rc' => 200,
 '_msg' => 'OK'
}
----------
HTTP/1.1 404 Not Found
Content-Type: text/html

----------
{
 '_content' => "",
 '_protocol' => 'HTTP/1.1',
 '_headers' => { "content-type" => "text/html"},
 '_rc' => 404,
 '_msg' => 'Not Found'
}
----------
HTTP/1.1 200 OK
Content-Type: text/html
FOO-BAR: BAZ

----------
{
 '_content' => "",
 '_protocol' => 'HTTP/1.1',
 '_headers' => { "content-type" => "text/html", "foo-bar" => 'BAZ'},
 '_rc' => 200,
 '_msg' => 'OK'
}
__HEADERS

my @tests = split '-'x10, $tests;
my $i = 0;
while (@tests) {
    $i++;
    my $header = shift @tests;
    my $expect = shift @tests;
    $header =~ s/^\n//;
    last unless $expect;
    my $res = parse_it($header);
    my $r   = eval($expect);
    is_deeply( $res, $r, 'test-' . $i) or diag(explain($res));
}
done_testing;


sub parse_it {
    my ($buf) = @_;
    my ($ret, $minor_version, $status, $msg, $headers) = parse_http_response($buf, HEADERS_AS_HASHREF);
    if ($ret > 0) {
        return +{
            _rc => $status,
            _msg => $msg,
            _headers => $headers,
            _protocol => "HTTP/1.$minor_version",
            _content => substr($buf, $ret),
        };
    } else {
        return undef;
    }
}

