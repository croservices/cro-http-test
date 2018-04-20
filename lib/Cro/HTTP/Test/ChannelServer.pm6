use Cro::Connection;
use Cro::Connector;
use Cro::HTTP::Client;
use Cro::HTTP::RequestParser;
use Cro::HTTP::ResponseSerializer;
use Cro::TCP;

class Cro::HTTP::Test::Client is Cro::HTTP::Client {
    has $.connector is required;
    method choose-connector($) {
        $!connector
    }
}

class Cro::HTTP::Test::Replier does Cro::Sink {
    has Channel $.out is required;
    
    method consumes() { Cro::TCP::Message }

    method sinker(Supply:D $pipeline) returns Supply:D {
        supply {
            whenever $pipeline {
                $!out.send(.data);
                LAST $!out.close;
            }
        }
    }
}
class Cro::HTTP::Test::Connection does Cro::Connection does Cro::Replyable {
    has Channel $.in .= new;
    has Channel $.out .= new;
    has $.replier = Cro::HTTP::Test::Replier.new(:$!out);

    method produces() { Cro::TCP::Message }

    method incoming() {
        supply whenever $!in.Supply -> $data {
            emit Cro::TCP::Message.new(:$data);
        }
    }
}

class Cro::HTTP::Test::Listener does Cro::Source {
    has Channel $.connection-channel is required;

    method produces() { Cro::HTTP::Test::Connection }

    method incoming() {
        $!connection-channel.Supply
    }
}

class Cro::HTTP::Test::Connector does Cro::Connector {
    has Channel $.connection-channel is required;

    class Transform does Cro::Transform {
        has Channel $.out is required;
        has Channel $.in is required;

        method consumes() { Cro::TCP::Message }
        method produces() { Cro::TCP::Message }

        method transformer(Supply $incoming --> Supply) {
            supply {
                whenever $incoming {
                    $!out.send(.data);
                }
                whenever $!in -> $data {
                    emit Cro::TCP::Message.new(:$data);
                    LAST done;
                }
            }.on-close({ $!out.close })
        }
    }

    method consumes() { Cro::TCP::Message }
    method produces() { Cro::TCP::Message }

    method connect(--> Promise) {
        start {
            my $in = Channel.new;
            my $out = Channel.new;
            my $connection = Cro::HTTP::Test::Connection.new(:$in, :$out);
            $!connection-channel.send($connection);
            Transform.new(out => $in, in => $out)
        }
    }
}

sub build-client-and-service(Cro::Transform $testee, %client-options, :$fake-auth, :$http) is export {
    die "fake-auth NYI" if $fake-auth !=== Any;
    my $connection-channel = Channel.new;
    my $connector = Cro::HTTP::Test::Connector.new(:$connection-channel);
    my $client = Cro::HTTP::Test::Client.new(:$connector, |%client-options, base-uri => 'http://test/');
    my $service = do if !$http.defined || $http eq '1' || $http eq '1.1' {
        Cro.compose:
            Cro::HTTP::Test::Listener.new(:$connection-channel),
            Cro::HTTP::RequestParser.new,
            $testee,
            Cro::HTTP::ResponseSerializer.new
    }
    else {
        die "Unsupported HTTP version '$http'";
    }
    return ($client, $service);
}
