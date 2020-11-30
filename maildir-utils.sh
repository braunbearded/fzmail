#!/bin/sh

get_recipients() {
    #$1 = path to maildir
    awk -F "|" '{print $4}' "$1" | xargs -I "{}" sh -c "find {} -type f ! -name '.*'" | \
        maddr | sort -u
}
