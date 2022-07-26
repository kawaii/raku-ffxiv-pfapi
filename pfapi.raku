use Cro::HTTP::Router;
use Cro::HTTP::Server;
use JSON::Class;
use Red;
use Redis::Async;
use LibUUID;
use Terminal::ANSIColor;

my $GLOBAL::RED-DB = database "Pg", :host(%*ENV<PFAPI_DB_HOST>), :database(%*ENV<PFAPI_DB_NAME>), :user(%*ENV<PFAPI_DB_USER>), :password(%*ENV<PFAPI_DB_PASSWORD>);
my $redis = Redis::Async.new(%*ENV<PFAPI_REDIS_HOST>);

model Character is table<pfapi_characters> does JSON::Class {
    has Int $.id is id;
    has Int $.tier is column;
    has Str $.comment is column;
    has DateTime $.date-added is column{ :type<timestamptz> } = DateTime.now;
    has Int $.author is column{ :type<bigint> };
}

model Encounter is table<pfapi_encounters> does JSON::Class {
    has Str $.series is id;
    has Int $.zone-id is id;
    has Int $.territory-type is id;
    has @.encounter-id is column{ :type<integer[]> };
    has Str $.title is column;
}

model User is table<pfapi_users> {
    has UUID $.uuid is id;
    has Str $.username is id;
    has Int $.discord-id is column{ :type<bigint> };
    has DateTime $.date-added is column{ :type<timestamptz> } = DateTime.now;
}

Character.^create-table: :if-not-exists;
Encounter.^create-table: :if-not-exists;
User.^create-table: :if-not-exists;

class Auth does Cro::HTTP::Middleware::Conditional {
    method process(Supply $requests) {
        my sub pass($request) {
            emit $request
        }
        my sub fail($request, $auth?) {
            note "[{ DateTime.now }] Failed authentication from { $request.connection.peer-host } (Auth: { $auth // 'N/A' })";
            emit Cro::HTTP::Response.new(:$request, :403status)
        }
        supply whenever $requests -> $request {
            with $request.header('Auth') -> $auth {
                my $is-auth = try { UUID.new($auth) };
                if $is-auth and User.^load(uuid => $auth) {
                    pass($request);
                }
                else {
                    fail($request, $auth);
                }
                next;
            }
            fail($request);
        }
    }
}

sub character-lookup(Int :$id) {
    # check the cache first
    my Bool $cached = True;
    my $character = $redis.get($id);
    # check the database if we didn't find it in the cache
    if !$character {
        $cached = False;
        $character = Character.^load($id).to-json;
        # cache the result we got from the database for 30 minutes
        if $character { $redis.setex($id, 1800, $character); }
    }
    my ($color, $state) = $cached ?? ('red', '[HIT]') !! ('blue', '[MISS]');
    note "[{ DateTime.now }]" ~ color($color)," $state " ~ color('reset'), "Performing lookup on $id";
    # return the lookup result
    return $character;
}

my $application = route {
    before Auth;
    get -> 'character', Int $id {
        my $character = character-lookup(:$id);
        if $character {
            content 'application/json', $character;
        } else {
            not-found;
        }
    }
    get -> 'encounters' {
        my $encounters = Encounter.^all;
        content 'application/json', ($encounters but JSON::Class).to-json;;
    }
}

my Cro::Service $service = Cro::HTTP::Server.new:
        :host<localhost>, :port<10000>, :$application;

$service.start;
react whenever signal(SIGINT) {
    $service.stop;
    exit;
}
