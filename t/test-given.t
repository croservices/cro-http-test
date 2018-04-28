use Cro::HTTP::Test;

sub routes() is export {
    use Cro::HTTP::Router;
    route {
        get -> 'cookies', :%cookies is cookie {
            content 'text/plain', %cookies.sort(*.key).map({ "{.key}={.value}" }).join(",");
        }
    }
}

plan 6;

test-service routes(), {
    test get('/cookies', cookies => { aa => 'foo' }),
        status => 200,
        content-type => 'text/plain',
        body => 'aa=foo';

    test-given cookies => { bb => 'bar' }, {
        test get('/cookies'),
            status => 200,
            content-type => 'text/plain',
            body => 'bb=bar';

        test get('/cookies', cookies => { aa => 'foo' }),
            status => 200,
            content-type => 'text/plain',
            body => 'aa=foo,bb=bar';

        test-given cookies => [ cc => 'baz' ], {
            test get('/cookies'),
                status => 200,
                content-type => 'text/plain',
                body => 'bb=bar,cc=baz';

            test get('/cookies', cookies => { aa => 'foo' }),
                status => 200,
                content-type => 'text/plain',
                body => 'aa=foo,bb=bar,cc=baz';

            test get('/cookies', cookies => { cc => 'win' }),
                status => 200,
                content-type => 'text/plain',
                body => 'bb=bar,cc=win';
        }
    }
}
