unit module Cro::HTTP::Test;
use Cro::HTTP::Client;
use Cro::MediaType;
use Cro::Transform;
use Cro::Uri;
use Test;

my class X::Cro::HTTP::Test::OnlyOneBody is Exception {
    method message() {
        "Can only use one of `body`, `body-blob`, `body-text`, or `json`"
    }
}

my class TestContext {
    has Cro::HTTP::Client $.client is required;
    has Str $.base-path = '';
    has %.request-options;
}

multi test-service(Cro::Transform $service, &tests, :$fake-auth, :$http,
                   *%client-options --> Nil) is export {
    ...
}

multi test-service(Str $uri, &tests, *%client-options --> Nil) is export {
    test-service-run Cro::HTTP::Client.new(base-uri => $uri, |%client-options), &tests;
}

sub test-service-run($client, &tests --> Nil) {
    my TestContext $*CRO-HTTP-TEST-CONTEXT .= new(:$client);
    tests();
}

multi test-given(Str $new-base, &tests, *%client-options --> Nil) is export {
    ...
}

multi test-given(&tests, *%client-options --> Nil) is export {
    ...
}

class TestRequest {
    has Str $.method is required;
    has Str $.path = '';
    has %.client-options;
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
        subtest {
            my $resp = get-response($ctx, $request);
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
            with $body {
                if $body-text.defined || $body-blob.defined || $json.defined {
                    die X::Cro::HTTP::Test::OnlyOneBody;
                }
                ok await($resp.body) ~~ $body, 'Body is acceptable';
            }
        };
    }
    else {
        die "Should use `test` within a `test-service` block";
    }
}

sub get-response($ctx, $request) {
    return await $ctx.client.request($request.method, $request.path, |$request.client-options);
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
