use strict;
use warnings;

use Test::More;

use HTTP::Parser::XS qw(parse_http_request);

# PATH_INFO is URL-decoded. A %00 in the path decodes to a NUL byte, and the
# decoded value must keep every byte: truncating at the NUL hands the
# application a different, shorter path than the one in REQUEST_URI, which a
# front-end proxy or filter may have checked. The pure-Perl backend already
# keeps the NUL; this pins both backends to the same answer.

diag "backend: $HTTP::Parser::XS::BACKEND";

sub parse_path {
    my $target = shift;
    my $req    = "GET $target HTTP/1.0\r\n\r\n";
    my %env;
    my $ret = parse_http_request($req, \%env);
    is $ret, length($req), "request for $target parses";
    return \%env;
}

# --- decoded NUL must not truncate PATH_INFO -------------------------------

my $env = parse_path('/public%00/admin?x=a%00b');
is length($env->{PATH_INFO}), 14, 'PATH_INFO keeps every decoded byte';
is $env->{PATH_INFO}, "/public\0/admin",
    'PATH_INFO is not truncated at a decoded NUL';
is $env->{QUERY_STRING}, 'x=a%00b',  'QUERY_STRING is stored raw';
is $env->{REQUEST_URI}, '/public%00/admin?x=a%00b', 'REQUEST_URI is stored raw';

$env = parse_path('/a%00');
is $env->{PATH_INFO}, "/a\0", 'trailing %00 keeps the NUL';

$env = parse_path('/%00%00x');
is $env->{PATH_INFO}, "/\0\0x", 'consecutive %00 escapes keep every NUL';

# --- behaviour the fix must not change -------------------------------------

$env = parse_path('/abc');
is $env->{PATH_INFO}, '/abc', 'path without escapes is unchanged';

$env = parse_path('/a%41b%2Fc');
is $env->{PATH_INFO}, '/aAb/c', 'ordinary escapes still decode';

$env = parse_path('/%E3%81%82');
is $env->{PATH_INFO}, "/\xE3\x81\x82", 'multi-byte escapes decode to bytes';
is length($env->{PATH_INFO}), 4, '... with the decoded length';

done_testing;
