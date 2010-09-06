#!/usr/bin/perl
use strict;
use warnings;

use Benchmark qw(cmpthese);
use HTTP::Parser;
use HTTP::Parser::XS qw(parse_http_request);

my $req = "GET /foo/bar/baz.html?key=value HTTP/1.0\r\n\r\n";

my $http_parser = HTTP::Parser->new();

cmpthese(-1, {
    'HTTP::Parser' => sub {
        my $status = $http_parser->add($req);
        if ($status == 0) {
            $http_parser->request();
        } else {
            die "oh!\n";
        }
    },
    'HTTP::Parser::XS' => sub {
        my %env;
        my $len = parse_http_request($req, \%env);
        if ($len >= 0) {
            # ok
        } else {
            die "agh!\n";
        }
    },
});
