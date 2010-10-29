#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use Benchmark ':all';
use HTTP::Parser::XS ':all';
use LWP::UserAgent;


my $buf = <<'...';
HTTP/1.0 200 OK
Date: Fri, 29 Oct 2010 05:19:06 GMT
Server: hi
Status: 200 OK
X-Transaction: 1414179016-1573-34157
ETag: "0694329108904124516f45127c9543d9"-gzip
Last-Modified: Fri, 29 Oct 2010 05:19:06 GMT
X-Runtime: 0.01082
Content-Type: text/html; charset=utf-8
Pragma: no-cache
X-Revision: DEV
Expires: Tue, 31 Mar 1981 05:00:00 GMT
Cache-Control: no-cache, no-store, must-revalidate, pre-check=0, post-check=0
Set-Cookie: auth_token=; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT
Set-Cookie: _twitter_sess=BJKL5252d3Hjkmode=block
X-Frame-Options: SAMEORIGIN
Vary: Accept-Encoding
Content-Encoding: gzip
Content-Length: 20
Connection: close

...
$buf =~ s/\015?\012/\015\012/;

if (my $url = shift @ARGV) {
    my $ua = LWP::UserAgent->new(parse_head => 0);
    my $res = $ua->head($url);
    die $res->status_line unless $res->is_success;
    $buf = $res->as_string;
}

# $buf is valid?
my ($ret, $minor_version, $status, $msg) = parse_http_response($buf, HEADER_NONE);
$ret > 0 or die "*** Cannot parse header ***\n$buf";

cmpthese(
    -1, {
        'none' => sub {
            parse_http_response($buf, HEADER_NONE);
        },
        'arrayref' => sub {
            parse_http_response($buf, HEADERS_AS_ARRAYREF);
        },
        'arrayref+special' => sub {
            my %special = (
                'connection'        => '',
                'content-length'    => undef,
                'location'          => '',
                'content-encoding'  => '',
                'transfer-encoding' => '',
            );
            parse_http_response(
                $buf,
                HEADERS_AS_ARRAYREF,
                \%special,
            );
        },
        'special' => sub {
            my %special = (
                'connection'        => '',
                'content-length'    => undef,
                'location'          => '',
                'content-encoding'  => '',
                'transfer-encoding' => '',
            );
            parse_http_response(
                $buf,
                HEADER_NONE,
                \%special,
            );
        },
        'hashref' => sub {
            parse_http_response($buf, HEADERS_AS_HASHREF);
        },
    },
);

