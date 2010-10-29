#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use Benchmark ':all';
use HTTP::Parser::XS ':all';

my $buf = join( '',
    "HTTP/1.0 200 OK\015\012",
    "Content-Length: 1234\015\012",
    "Connection: close\015\012",
    "Location: http://mixi.jp/\015\012",
    "Transfer-Encoding: chunked\015\012",
    "Content-Encoding: gzip\015\012",
    "X-Foo: Bar\015\012",
    "\015\012" );

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

