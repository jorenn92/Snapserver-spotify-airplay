FROM alpine:latest AS LIBRE-BUILDER

ARG TARGETPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM:-linux/amd64}

WORKDIR /


RUN apk update

# Build librespot
RUN apk -U add curl cargo portaudio-dev protobuf-dev avahi-dev git \
 && git clone "https://github.com/librespot-org/librespot.git" \
  && cd librespot \
 && git checkout master \
 && cargo build --release --no-default-features --features with-dns-sd
 
# Build react frontend 
FROM node:lts-alpine AS REACT-BUILDER
RUN apk -U add git \
 && git clone "https://github.com/jorenn92/Snapweb.git" \
 && cd Snapweb \
 && npm ci \
 && npm run build

RUN apk update

# Build librespot
WORKDIR /
RUN apk -U add curl cargo portaudio-dev protobuf-dev avahi-dev git \
 && git clone "https://github.com/librespot-org/librespot.git" \
  && cd librespot \
 && git checkout master \
 && cargo build --release --no-default-features --features with-dns-sd

FROM alpine:latest

ARG TARGETPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM:-linux/amd64}

RUN echo "https://dl-cdn.alpinelinux.org/alpine/edge/testing/" >> /etc/apk/repositories
RUN apk add --no-cache bash snapcast sed avahi-compat-libdns_sd

# Build Shairport-sync
RUN env \
&& apk -U add \
	git \
	build-base \
	autoconf \
	automake \
	libtool \
	alsa-lib-dev \
	libdaemon-dev \
	popt-dev \
	libressl-dev \
	soxr-dev \
	avahi-dev \
	xmltoman \
	libconfig-dev \
	libstdc++ \
&&	cd /root \
&&	git clone https://github.com/mikebrady/alac \
&&  cd /root/alac \
&&	autoreconf -fi \
&& 	./configure \
&&	make \
&&	make install \
&& cd /root \
&& git clone "https://github.com/mikebrady/shairport-sync.git" \
&& cd /root/shairport-sync \
&& git checkout master \
&& autoreconf -i -f \
&& ./configure \
        --with-pipe \
		--with-stdout \
        --with-avahi \
        --with-ssl=openssl \
        --with-metadata \
		--with-soxr \
		--with-apple-alac \
&& make \
&& make install \
&& ldconfig / \
&& cd / \
&& apk --purge del \
		git \
        build-base \
        autoconf \
        automake \
        libtool \
        alsa-lib-dev \
        libdaemon-dev \
        popt-dev \
        libressl-dev \
        soxr-dev \
        avahi-dev \
        libconfig-dev \
        xmltoman \
        libconfig-dev \
        libstdc++ \
&& apk add \
        dbus \
        alsa-lib \
        libdaemon \
        popt \
        libressl \
        soxr \
        avahi \
        libconfig \
        libstdc++ \
&& rm -rf \
        /etc/ssl \
        /var/cache/apk/* \
        /lib/apk/db/* \
        /root/shairport-sync \
		/root/alac \
		/usr/share/snapserver/snapweb

COPY run.sh /
COPY shairport-sync.conf /usr/local/etc/shairport-sync-sample.conf
COPY --from=LIBRE-BUILDER /librespot/target/release/librespot /usr/local/bin/
COPY --from=LIBRE-BUILDER /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=REACT-BUILDER /Snapweb/build /usr/share/snapserver/snapweb


RUN chmod +x /run.sh && \
	mkdir -p /var/run/dbus
	
CMD ["/run.sh"]
ENV AVAHI_COMPAT_NOWARN=1

ENV DEVICE_NAME=Snapcast
ENV SPOTIFY_DEVICES="Snapcast"
ENV AIRPLAY_DEVICES="Snapcast"


EXPOSE 1704/tcp 1705/tcp