FROM shuppet/eredis:latest as EREDIS

FROM jjmerelo/alpine-raku:latest

COPY --from=EREDIS /usr/local/lib/liberedis.so /usr/local/lib/liberedis.so

USER root
RUN set -ex; \
	\
	apk add --no-cache --virtual .build-deps \
                build-base \
                libpq \
                libressl-dev

USER raku
RUN set -ex; \
        \
	HOME=/home/raku && zef install --/test \
		Cro::HTTP::Router \
		Cro::HTTP::Server \
		JSON::Class \
		Red \
		Redis::Async \
		LibUUID \
		Terminal::ANSIColor

USER root
RUN set -ex; \
	apk del .build-deps

USER raku
COPY pfapi.raku /opt/pfapi.raku
CMD ["/usr/bin/raku", " --ll-exception", "/opt/pfapi.raku"]
