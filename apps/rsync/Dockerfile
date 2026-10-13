FROM alpine:3.23

RUN apk add --no-cache rsync

EXPOSE 873

ENTRYPOINT ["rsync"]
CMD ["--daemon", "--no-detach", "--config=/etc/rsyncd.conf"]
