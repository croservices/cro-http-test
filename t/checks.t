use Cro::HTTP::Test;

sub routes() is export {
    use Cro::HTTP::Router;
    route {
        get -> 'text' {
            content 'text/plain', 'just a simple text body';
        }
        get -> 'binary' {
            content 'application/octet-stream', Blob.new(1,2,4,9);
        }
    }
}

plan 6;

test-service routes(), {
    test get('/text'),
        status => 200,
        content-type => 'text/plain',
        body-text => 'just a simple text body';
    test get('/text'),
        status => 200,
        content-type => 'text/plain',
        body-text => /simple/;
    test get('/text'),
        status => 200,
        content-type => 'text/plain',
        body-text => *.chars == 23;
    test get('/text'),
        status => 200,
        content-type => 'text/plain',
        body-blob => *.elems == 23;

    test get('/binary'),
        status => 200,
        content-type => 'application/octet-stream',
        body-blob => * eq Blob.new(1,2,4,9);
    test get('/binary'),
        status => 200,
        content-type => 'application/octet-stream',
        body-blob => *.elems == 4;
}
