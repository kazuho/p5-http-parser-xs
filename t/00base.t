use Test::More tests => 1;

BEGIN {
    use_ok('HTTP::Parser::XS');
}
diag "Testing HTTP::Parser::XS/$HTTP::Parser::XS::VERSION",
     " ($HTTP::Parser::XS::BACKEND)";
