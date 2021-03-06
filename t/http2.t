use Cro::HTTP::Test;

sub routes() is export {
    use Cro::HTTP::Router;
    route {
        get -> {
            content 'text/plain', 'Nothing to see here';
        }
        post -> 'add' {
            request-body 'application/json' => -> (:$x!, :$y!) {
                content 'application/json', { :result($x + $y) };
            }
        }
    }
}

plan 4;

test-service routes(), :http<2>, {
    test get('/'),
        status => 200,
        content-type => 'text/plain',
        body => /:i nothing/;

    test-given '/add', {
        test post(json => { :x(37), :y(5) }),
            status => 200,
            json => { :result(42) };

        is-bad-request post(json => { :x(37) });

        is-method-not-allowed get(json => { :x(37) });
    }
}
