unit module Cro::HTTP::Test;
use Cro::Transform;
use Test;

multi test-service(Cro::Transform $service, &tests, :$fake-auth, :$http,
                   *%client-options --> Nil) is export {
    ...
}

multi test-service(Str $uri, &tests --> Nil) is export {
    ...
}

multi test-given(Str $new-base, &tests, *%client-options --> Nil) is export {
    ...
}

multi test-given(&tests, *%client-options --> Nil) is export {
    ...
}

class TestRequest {
    has Str $.method is required;
    has Str $.path;
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
         :$body-test, :$body-blob, :$body, :$json --> Nil) is export {
    ...
}

# Re-export plan and done-testing from Test, and use it ourselves for doing the
# test assertions.
EXPORT::DEFAULT::<&plan> := &plan;
EXPORT::DEFAULT::<&done-testing> := &done-testing;
