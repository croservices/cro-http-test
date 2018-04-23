unit module Cro::HTTP::Test;
use Cro::HTTP::Client;
use Cro::HTTP::Test::ChannelServer;
use Cro::MediaType;
use Cro::Transform;
use Cro::Uri;
use Test;

my class X::Cro::HTTP::Test::OnlyOneBody is Exception {
    method message() {
        "Can only use one of `body`, `body-blob`, `body-text`, or `json`"
    }
}
my class X::Cro::HTTP::Test::BadHeaderTest is Exception {
    has $.got;
    method message() {
        "Header tests should be a Pair or an Iterable of Pair, but got '$!got.perl()'"
    }
}

my class TestContext {
    has Cro::HTTP::Client $.client is required;
    has Str $.base-path = '';
    has %.client-options;

    method derive($add-base, %add-options) {
        my $new-base = merge-path($!base-path, $add-base);
        my %new-options := merge-options(%!client-options, %add-options);
        return TestContext.new(:$!client, :base-path($new-base), :client-options(%new-options));
    }
}

multi test-service(Cro::Transform $testee, &tests, :$fake-auth, :$http,
                   *%client-options --> Nil) is export {
    my ($client, $service) = build-client-and-service($testee, %client-options, :$fake-auth, :$http);
    $service.start;
    my $started = True;
    LEAVE $service.stop if $started;
    test-service-run $client, &tests;
}

multi test-service(Str $uri, &tests, *%client-options --> Nil) is export {
    test-service-run Cro::HTTP::Client.new(base-uri => $uri, |%client-options), &tests;
}

sub test-service-run($client, &tests --> Nil) {
    my TestContext $*CRO-HTTP-TEST-CONTEXT .= new(:$client);
    tests();
}

multi test-given(Str $new-base, &tests, *%client-options --> Nil) is export {
    my TestContext $orig-context = $*CRO-HTTP-TEST-CONTEXT;
    {
        my $*CRO-HTTP-TEST-CONTEXT = $orig-context.derive($new-base, %client-options);
        tests();
    }
}

multi test-given(&tests, *%client-options --> Nil) is export {
    my TestContext $orig-context = $*CRO-HTTP-TEST-CONTEXT;
    {
        my $*CRO-HTTP-TEST-CONTEXT = $orig-context.derive(Nil, %client-options);
        tests();
    }
}

class TestRequest {
    has Str $.method is required;
    has Str $.path = '';
    has %.client-options;
    submethod TWEAK() {
        with %!client-options<json> -> $json {
            %!client-options<content-type> ||= 'application/json';
            %!client-options<body> = $json;
            %!client-options<json>:delete;
        }
    }
}

multi request(Str $method, Str $path, *%client-options --> TestRequest) is export {
    TestRequest.new(:$method, :$path, :%client-options)
}
multi request(Str $method, *%client-options --> TestRequest) is export {
    TestRequest.new(:$method, :%client-options)
}

multi get(Str $path, *%client-options --> TestRequest) is export {
    request('GET', $path, |%client-options)
}
multi get(*%client-options --> TestRequest) is export {
    request('GET', |%client-options)
}

multi post(Str $path, *%client-options --> TestRequest) is export {
    request('POST', $path, |%client-options)
}
multi post(*%client-options --> TestRequest) is export {
    request('POST', |%client-options)
}

multi put(Str $path, *%client-options --> TestRequest) is export {
    request('PUT', $path, |%client-options)
}
multi put(*%client-options --> TestRequest) is export {
    request('PUT', |%client-options)
}

multi delete(Str $path, *%client-options --> TestRequest) is export {
    request('DELETE', $path, |%client-options)
}
multi delete(*%client-options --> TestRequest) is export {
    request('DELETE', |%client-options)
}

multi patch(Str $path, *%client-options --> TestRequest) is export {
    request('PATCH', $path, |%client-options)
}
multi patch(*%client-options --> TestRequest) is export {
    request('PATCH', |%client-options)
}

multi head(Str $path, *%client-options --> TestRequest) is export {
    request('HEAD', $path, |%client-options)
}
multi head(*%client-options --> TestRequest) is export {
    request('HEAD', |%client-options)
}

sub test(TestRequest:D $request, :$status, :$content-type, :header(:$headers),
         :$body-text, :$body-blob, :$body, :$json --> Nil) is export {
    with $*CRO-HTTP-TEST-CONTEXT -> $ctx {
        my $method = $request.method;
        my $path = merge-path($ctx.base-path, $request.path);
        subtest "$method $path" => {
            my %options := merge-options($ctx.client-options, $request.client-options);
            my $resp = get-response($ctx.client, $method, $path, %options);
            with $status {
                when Int {
                    is $resp.status, $status, 'Status is acceptable';
                }
                default {
                    ok $resp.status ~~ $status, 'Status is acceptable';
                }
            }
            with $content-type {
                when Cro::MediaType {
                    test-media-type($resp.content-type, $_);
                }
                when Str {
                    test-media-type($resp.content-type, Cro::MediaType.parse($_));
                }
                default {
                    ok $resp.content-type ~~ $content-type, 'Content type is acceptable';
                }
            }
            with $headers {
                for .list {
                    when Pair {
                        my $header-name = .key;
                        my $got-value = $resp.header($header-name);
                        given .value {
                            when Str {
                                is $got-value, $_, "$header-name header";
                            }
                            default {
                                ok $got-value ~~ $_, "$header-name header";
                            }
                        }
                    }
                    default {
                        die X::Cro::HTTP::Test::BadHeaderTest.new(got => $_);
                    }
                }
            }
            with $json {
                if $body.defined || $body-text.defined || $body-blob.defined {
                    die X::Cro::HTTP::Test::OnlyOneBody;
                }
                without $content-type {
                    given $resp.content-type {
                        ok .type eq 'application' && .subtype-name eq 'json' || .suffix eq 'json',
                            'Content type is recognized as a JSON one';
                    }
                }
                is-deeply await($resp.body), $json, 'Body is acceptable';
            }
            orwith $body {
                if $body-text.defined || $body-blob.defined {
                    die X::Cro::HTTP::Test::OnlyOneBody;
                }
                ok await($resp.body) ~~ $body, 'Body is acceptable';
            }
            orwith $body-text {
                if $body-blob.defined {
                    die X::Cro::HTTP::Test::OnlyOneBody;
                }
                ok await($resp.body-text) ~~ $body-text, 'Body is acceptable';
            }
            orwith $body-blob {
                ok await($resp.body-blob) ~~ $body-blob, 'Body is acceptable';
            }
        };
    }
    else {
        die "Should use `test` within a `test-service` block";
    }
}

sub merge-path($base, $rel) {
    return $base unless $rel;
    return $rel unless $base;
    return Cro::Uri.parse-ref($base).add($rel).Str;
}

sub merge-options(%base, %new) {
    return %base unless %new;
    return %new unless %base;
    die "Merging options NYI";
}

sub get-response($client, $method, $path, %options) {
    return await $client.request($method, $path, %options);
    CATCH {
        when X::Cro::HTTP::Error {
            return .response;
        }
    }
}

sub test-media-type(Cro::MediaType $got, Cro::MediaType $expected) {
    if $expected.parameters -> @params {
        subtest 'Content type is acceptable' => {
            is $got.type-and-subtype, $expected.type-and-subtype, 'Media type and subtype are correct';
            for @params {
                ok any($got.parameters) eq $_, "Have parameter $_";
            }
        }
    }
    else {
        is $got.type-and-subtype, $expected.type-and-subtype, 'Content type is acceptable';
    }
}

# Re-export plan and done-testing from Test, and use it ourselves for doing the
# test assertions.
EXPORT::DEFAULT::<&plan> := &plan;
EXPORT::DEFAULT::<&done-testing> := &done-testing;
