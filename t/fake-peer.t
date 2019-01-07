use Cro::HTTP::Test;

sub routes() {
    use Cro::HTTP::Router;
    route {
        get -> {
            content 'application/json', {
                host => request.connection.peer-host,
                port => request.connection.peer-port
            }
        }
    }
}

test-service routes(), peer-host => '23.45.67.99', peer-port => 4242, {
    test get('/'),
            status => 200,
            json => { host => '23.45.67.99', port => 4242 };
}

done-testing;
