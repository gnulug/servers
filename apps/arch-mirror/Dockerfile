# Adapted from https://github.com/XigenIO/Docker-ArchMirror
FROM alpine:3.23

RUN apk add --update \
    rsync \
    openssh-client \
    bash \
    curl  \
    && rm -rf /var/cache/apk/* \
    && mkdir /data

COPY entrypoint.sh /entrypoint.sh

RUN chmod a+x /entrypoint.sh

VOLUME /data

ENTRYPOINT ["/entrypoint.sh"]
