use strict;
use warnings;
use Test::Requires 'Plack::Middleware::Deflater', 'Compress::Raw::Zlib';
use Furl;
use Test::TCP;
use Test::More;

use Plack::Request;
use File::Temp;

use t::Slowloris;

my $n = 10;
my $CONTENT = 'OK! YAY!' x 10;
test_tcp(
    client => sub {
        my $port = shift;
        my $furl = Furl->new();
        for my $encoding (qw/gzip deflate/) {
            for(1 .. $n) {
                note "normal $_ $encoding";
                my ( $code, $msg, $headers, $content ) =
                    $furl->request(
                        url        => "http://127.0.0.1:$port/",
                        headers    => ['Accept-Encoding' => $encoding],
                    );
                is $code, 200, "request()";
                is Furl::Util::header_get($headers, 'content-encoding'), $encoding;
                is($content, $CONTENT) or do { require Devel::Peek; Devel::Peek::Dump($content) };
            }

            for(1 .. $n) {
                note "to filehandle $_ $encoding";
                open my $fh, '>', \my $content;
                my ( $code, $msg, $headers ) =
                    $furl->request(
                        url        => "http://127.0.0.1:$port/",
                        headers    => ['Accept-Encoding' => $encoding],
                        write_file => $fh,
                    );
                is $code, 200, "request()";
                is Furl::Util::header_get($headers, 'content-encoding'), $encoding;
                is($content, $CONTENT) or do { require Devel::Peek; Devel::Peek::Dump($content) };
            }

            for(1 .. $n){
                note "to callback $_ $encoding";
                my $content = '';
                my ( $code, $msg, $headers ) =
                    $furl->request(
                        url        => "http://127.0.0.1:$port/",
                        headers    => ['Accept-Encoding' => $encoding],
                        write_code => sub { $content .= $_[3] },
                    );
                is $code, 200, "request()";
                is Furl::Util::header_get($headers, 'content-encoding'), $encoding;
                is($content, $CONTENT) or do { require Devel::Peek; Devel::Peek::Dump($content) };
            }
        }

        done_testing;
    },
    server => sub {
        my $port = shift;
        Slowloris::Server->new( port => $port )->run(
            Plack::Middleware::Deflater->wrap(
                sub {
                    my $env     = shift;
                    return [
                        200,
                        [ 'Content-Length' => length($CONTENT) ],
                        [$CONTENT]
                    ];
                }
            )
        );
    }
);
