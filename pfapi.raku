use Cro::HTTP::Router;
use Cro::HTTP::Server;
use JSON::Class;
use Red;
use LibUUID;

my $GLOBAL::RED-DB = database "Pg", :host<localhost>, :database<pfapi>, :user<pfapi>, :password<password>;

model Character is table<pfapi_characters> does JSON::Class {
    has Int $.id is id;
    has Int $.tier is column;
    has Str $.comment is column;
    has DateTime $.date-added is column{ :type<timestamptz> } = DateTime.now;
    has Int $.author is column{ :type<bigint> };
}

model User is table<pfapi_users> {
    has UUID $.uuid is id;
    has Str $.username is id;
    has Int $.discord-id is column{ :type<bigint> };
    has DateTime $.date-added is column{ :type<timestamptz> } = DateTime.now;
}

Character.^create-table: :if-not-exists;
User.^create-table: :if-not-exists;

class Auth does Cro::HTTP::Middleware::Conditional {
    method process(Supply $requests) {
        supply whenever $requests -> $request {
            whenever $request.body -> %body {
                if User.^load(uuid => %body<auth>) {
                    emit $request;
                } else {
                    note "[{ DateTime.now }] Failed authentication from { $request.connection.peer-host } (Auth: { %body<auth> })";
                    emit Cro::HTTP::Response.new(:$request, :403status);
                }
            }
        }
    }
}

my $application = route {
    before Auth;
    get -> 'character', $id {
        my $character = Character.^load($id);
        note "[{ DateTime.now }] Performing lookup on $id";
        if $character {
            content 'application/json', $character.to-json;
        } else {
            not-found;
        }
    }
}

my Cro::Service $service = Cro::HTTP::Server.new:
        :host<localhost>, :port<10000>, :$application;

$service.start;
react whenever signal(SIGINT) {
    $service.stop;
    exit;
}