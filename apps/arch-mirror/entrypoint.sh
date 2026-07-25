#!/bin/bash

# Adapted from https://github.com/XigenIO/Docker-ArchMirror
# and https://gitlab.archlinux.org/archlinux/infrastructure/-/blob/master/roles/syncrepo/files/syncrepo-template.sh

# This is a simple mirroring script. To save bandwidth it first checks a
# timestamp via HTTP and only runs rsync when the timestamp differs from the
# local copy. As of 2016, a single rsync run without changes transfers roughly
# 6MiB of data which adds up to roughly 250GiB of traffic per month when rsync
# is run every minute. Performing a simple check via HTTP first can thus save a
# lot of traffic.

# Directory where the repo is stored locally. Example: /srv/repo
target="/data"

# Directory where files are downloaded to before being moved in place.
# This should be on the same filesystem as $target, but not a subdirectory of $target.
# Example: /srv/tmp
tmp="/tmp/data"

# Lockfile path
lock="/var/lock/syncrepo.lck"

# If you want to limit the bandwidth used by rsync set this.
# Use 0 to disable the limit.
# The default unit is KiB (see man rsync /--bwlimit for more)
bwlimit=0

# The source URL of the mirror you want to sync from.
# If you are a tier 1 mirror use rsync.archlinux.org, for example like this:
# rsync://rsync.archlinux.org/ftp_tier1
# Otherwise chose a tier 1 mirror from this list and use its rsync URL:
# https://www.archlinux.org/mirrors/
# source_url=''

# Set to 1 only if the mirror supports rsync over TLS (port 874).
# Most mirrors do not,
# See https://wiki.archlinux.org/title/DeveloperWiki:NewMirrors#rsync_over_TLS
tls="${tls:-0}"

# An HTTP(S) URL pointing to the 'lastupdate' file on your chosen mirror.
# If you are a tier 1 mirror use: https://rsync.archlinux.org/lastupdate
# Otherwise use the HTTP(S) URL from your chosen mirror.
# lastupdate_url=''

#### END CONFIG

[ ! -d "${target}" ] && mkdir -p "${target}"
[ ! -d "${tmp}" ] && mkdir -p "${tmp}"

exec 9>"${lock}"
flock -n 9 || exit

# Cleanup any temporary files from old run that might remain.
# Note: You can skip this if you have rsync newer than 3.2.3
# not affected by https://github.com/WayneD/rsync/issues/192
# find "${target}" -name '.~tmp~' -exec rm -r {} +

rsync_cmd() {
    local -a cmd
    if ((tls>0)); then
        cmd=(rsync-ssl --type=openssl)
    else
        cmd=(rsync)
    fi
    cmd+=(-rlptH --safe-links --delete-delay --delay-updates
        "--timeout=600" --no-motd "--temp-dir=${tmp}" ${VERBOSE})

    if [ -t 0 ]; then
        cmd+=(-h -v --progress)
    else
        cmd+=(--quiet)
    fi

    if ((bwlimit>0)); then
        cmd+=("--bwlimit=$bwlimit")
    fi

    "${cmd[@]}" "$@"
}

# Format a unix-timestamp file (lastsync, lastupdate, …) as a human-readable date.
file_date() {
    TZ=America/Chicago date -d @"$(cat "$1")"
}

while true; do
    # Without a tty, skip the full sync when lastupdate is unchanged.
    # With a tty (or on first run), always do a full sync.
    if ! [ -t 0 ] && [[ -f "$target/lastupdate" ]] \
        && diff -b <(curl -Ls "$lastupdate_url") "$target/lastupdate" >/dev/null; then
        # Unchanged: only refresh lastsync for Arch mirror statistics
        echo "Mirror was last synced $(file_date "${target}/lastsync"), no changes since $(file_date "${target}/lastupdate")."
        rsync_cmd "$source_url/lastsync" "$target/lastsync" || exit 1
    else
        if [[ -f "$target/lastupdate" ]]; then
            echo "Upstream changed since $(file_date "${target}/lastupdate"), starting full sync..."
        else
            echo "No local mirror yet, starting initial full sync..."
        fi

        rsync_cmd \
            --exclude='*.links.tar.gz*' \
            --exclude='/other' \
            --exclude='/sources' \
            "${source_url}" \
            "${target}" \
            || exit 1

        echo "Full sync finished. Mirror last synced $(file_date "${target}/lastsync"), upstream last updated $(file_date "${target}/lastupdate")."
    fi

    # Do not sync more often than every hour; at least once a day is enough.
    echo "Sleeping until $(TZ=America/Chicago date -d @$(($(date +%s) + 10800))) (3 hours from now)..."
    sleep 10800
done
