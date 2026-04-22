FROM debian:trixie-slim@sha256:4ffb3a1511099754cddc70eb1b12e50ffdb67619aa0ab6c13fcd800a78ef7c7a AS trixie-slim-backports
RUN echo "deb http://deb.debian.org/debian trixie-backports main" > /etc/apt/sources.list.d/backports.list

FROM trixie-slim-backports AS builder
ARG VERSION

RUN <<"EOF"
set -eux
export DEBIAN_FRONTEND=noninteractive
apt-get -y update
apt-get install -y --no-install-recommends \
    automake \
    build-essential \
    ca-certificates \
    git \
    libtool \
    make \
    pkg-config \
    libcurl4-openssl-dev \
    libogg-dev \
    libspeex-dev \
    libssl-dev \
    libtheora-dev \
    libvorbis-dev \
    libxml2-dev \
    libxslt1-dev \
    libigloo-dev/trixie-backports \
    librhash-dev
rm -rf /var/lib/apt/lists/*
EOF

WORKDIR /build
ADD icecast-$VERSION.tar.gz .
RUN if test ! -d icecast-$VERSION; then mv icecast-* icecast-$VERSION; fi

WORKDIR /build/icecast-$VERSION
RUN ./configure \
    --prefix=/usr \
    --sysconfdir=/etc \
    --localstatedir=/var

RUN make
RUN make install DESTDIR=/build/output

FROM trixie-slim-backports AS runner

RUN <<"EOF"
set -eux
export DEBIAN_FRONTEND=noninteractive
apt-get -y update
apt-get install -y --no-install-recommends \
    ca-certificates \
    media-types \
    libcurl4 \
    libogg0 \
    libspeex1 \
    libssl3t64 \
    libtheora0 \
    libvorbis0a \
    libxml2  \
    libxslt1.1 \
    libigloo0t64/trixie-backports \
    librhash1
rm -rf /var/lib/apt/lists/*
EOF

ENV USER=icecast

RUN useradd --no-create-home $USER

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint
COPY xml-edit.sh /usr/local/bin/xml-edit
RUN chmod +x \
    /usr/local/bin/docker-entrypoint \
    /usr/local/bin/xml-edit

COPY --from=builder /build/output /
RUN cp /etc/icecast.xml /etc/icecast-cfg.xml
RUN xml-edit errorlog - /etc/icecast-cfg.xml

RUN mkdir -p /var/log/icecast && \
    chown $USER /etc/icecast-cfg.xml /var/log/icecast

EXPOSE 8000
ENTRYPOINT ["docker-entrypoint"]
USER $USER
CMD ["icecast", "-c", "/etc/icecast-cfg.xml"]
