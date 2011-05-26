package HTTP::Parser::XS::PP;
use strict;
use warnings;
use utf8;

sub HTTP::Parser::XS::parse_http_request {
    my($chunk, $env) = @_;
    Carp::croak("second param to parse_http_request should be a hashref") unless (ref $env|| '') eq 'HASH';

    # pre-header blank lines are allowed (RFC 2616 4.1)
    $chunk =~ s/^(\x0d?\x0a)+//;
    return -2 unless length $chunk;

    # double line break indicates end of header; parse it
    if ($chunk =~ /^(.*?\x0d?\x0a\x0d?\x0a)/s) {
        return _parse_header($chunk, length $1, $env);
    }
    return -2;  # still waiting for unknown amount of header lines
}

sub _parse_header {
    my($chunk, $eoh, $env) = @_;

    my $header = substr($chunk, 0, $eoh,'');
    $chunk =~ s/^\x0d?\x0a\x0d?\x0a//;

    # parse into lines
    my @header  = split /\x0d?\x0a/,$header;
    my $request = shift @header;

    # join folded lines
    my @out;
    for(@header) {
        if(/^[ \t]+/) {
            return -1 unless @out;
            $out[-1] .= $_;
        } else {
            push @out, $_;
        }
    }

    # parse request or response line
    my $obj;
    my $minor;

    my ($method,$uri,$http) = split / /,$request;
    return -1 unless $http and $http =~ /^HTTP\/1\.(\d+)$/;
    $minor = $1;

    my($path, $query) = ( $uri =~ /^([^?#]*)(?:\?([^#]*))?/s );
    # following validations are just needed to pass t/01simple.t
    if ($path =~ /%(?:[0-9a-f][^0-9a-f]|[^0-9a-f][0-9a-f])/i) {
        # invalid char in url-encoded path
        return -1;
    }
    if ($path =~ /%(?:[0-9a-f])$/i) {
        # partially url-encoded
        return -1;
    }

    $env->{REQUEST_METHOD}  = $method;
    $env->{REQUEST_URI}     = $uri;
    $env->{SERVER_PROTOCOL} = "HTTP/1.$minor";
    ($env->{PATH_INFO}      = $path) =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
    $env->{QUERY_STRING} = $query || '';
    $env->{SCRIPT_NAME}  = '';

    # import headers
    my $token = qr/[^][\x00-\x1f\x7f()<>@,;:\\"\/?={} \t]+/;
    my $k;
    for my $header (@out) {
        if ( $header =~ s/^($token): ?// ) {
            $k = $1;
            $k =~ s/-/_/g;
            $k = uc $k;

            if ($k !~ /^(?:CONTENT_LENGTH|CONTENT_TYPE)$/) {
                $k = "HTTP_$k";
            }
        } elsif ( $header =~ /^\s+/) {
            # multiline header
        } else {
            return -1;
        }

        if (exists $env->{$k}) {
            $env->{$k} .= ", $header";
        } else {
            $env->{$k} = $header;
        }
    }

    return $eoh;
}

# ----------------------------------------------------------

my %PARSER_FUNC = (
    HTTP::Parser::XS::HEADERS_NONE()        => \&_parse_as_none,
    HTTP::Parser::XS::HEADERS_AS_HASHREF()  => \&_parse_as_hashref,
    HTTP::Parser::XS::HEADERS_AS_ARRAYREF() => \&_parse_as_arrayref,
);

sub HTTP::Parser::XS::parse_http_response {
    my ($str, $header_format, $special_headers) = @_;
    return -2 unless $str;

    my $len = length $str;
    
    my ($sl, $remain) = split /\r?\n/, $_[0], 2;
    my ($proto, $rc, $msg) = split(' ', $sl, 3);
    return -1 unless $proto =~m{^HTTP/1.(\d)};
    my $minor_version = $1;
    return -1 unless $rc =~m/^\d+$/;

    my ($header_str, $content) = split /\r?\n\r?\n/, $remain, 2;

    my $parser_func = $PARSER_FUNC{$header_format};
    die 'unknown header format: '. $header_format unless $parser_func;

    my $header = $parser_func->($header_str, $special_headers || +{});

    return -2 if ($str !~/\r?\n\r?\n/ && $remain !~/\r?\n\r?\n/ && !defined $content);
    my $parsed = $len - (defined $content ? length $content : 0);

    return ($parsed, $minor_version, $rc, $msg, $header);
}

# return special headers only
sub _parse_as_none {
    my ($str, $special) = @_;
    return unless defined $str;
    return unless keys %$special;

    my ($field, $value, $f);
    for ( split /\r?\n/, $str ) {
        if ( defined $field ) {
            if ( ord == 9 || ord == 32 ) {
                $value .= "\n$_";
                next;
            }
            $f = lc($field); 
            exists $special->{$f} and $special->{$f} = $value;
        }
        ( $field, $value ) = split /[ \t]*: ?/, $_, 2;
    }
    if ( defined $field ) {
        $f = lc($field); 
        exists $special->{$f} and $special->{$f} = $value;
    }
}

# return headers as arrayref
sub _parse_as_arrayref {
    my ($str, $special) = @_;
    return [] unless defined $str;

    my (@headers, $field, $value, $f );
    for ( split /\r?\n/, $str ) {
        if ( defined $field ) {
            if ( ord == 9 || ord == 32 ) {
                $value .= "\n$_";
                next;
            }
            $f = lc($field); 
            push @headers, $f, $value;
            exists $special->{$f} and $special->{$f} = $value;
        }
        ( $field, $value ) = split /[ \t]*: ?/, $_, 2;
    }
    if ( defined $field ) {
        $f = lc($field); 
        push @headers, $f, $value; 
        exists $special->{$f} and $special->{$f} = $value;
    }
    return \@headers;
}

# return headers as HTTP::Header compatible HashRef
sub _parse_as_hashref {
    my ($str, $special) = @_;
    return +{} unless defined $str;
    
    my ( %self, $field, $value, $f );
    for ( split /\r?\n/, $str ) {
        if ( defined $field ) {
            if ( ord == 9 || ord == 32 ) {
                $value .= "\n$_";
                next;
            }
            $f = lc($field); 
            if ( defined $self{$f} ) {
                my $h = $self{$f};
                ref($h) eq 'ARRAY'
                  ? push( @$h, $value )
                  : ( $self{$f} = [ $h, $value ] );
            }
            else { $self{$f} = $value }
        }
        ( $field, $value ) = split /[ \t]*: ?/, $_, 2;
    }
    if ( defined $field ) {
        $f = lc($field); 
        if ( defined $self{$f} ) {
            my $h = $self{$f};
            ref($h) eq 'ARRAY'
              ? push( @$h, $value )
              : ( $self{$f} = [ $h, $value ] );
        }
        else { $self{$f} = $value }
    }
    return \%self;
}

1;

