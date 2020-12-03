#!/bin/sh

get_recipients() {
    #$1 = path to maildir
    awk -F "|" '{print $4}' "$1" | xargs -I "{}" sh -c "find {} -type f ! -name '.*'" | \
        maddr | sort -u
}

set_flag_mail() {
    #$1 = path to mail
    #$2 = new flags
    current_flags="$(echo "$1" | grep -Eo "2,.*" | cut -c 3-)"
    all_flags="$(echo "$current_flags$2" | sed 's/./&\n/g' | sort -u | tr -d '\n')"
    new_path="$(echo "$1" | awk -F "2," -v flags="$all_flags" \
        '{print $1 "2," flags}')"
    [ "$1" != "$new_path" ] && mv "$1" "$new_path"
    echo "$new_path"
}

remove_flag_mail() {
    #$1 = path to mail
    #$2 = new flags
    current_flags="$(echo "$1" | grep -Eo "2,.*" | cut -c 3-)"
    all_flags="$(echo "$current_flags$2" | sed 's/./&\n/g' | sort | uniq -u | tr -d '\n')"
    new_path="$(echo "$1" | awk -F "2," -v flags="$all_flags" \
        '{print $1 "2," flags}')"
    [ "$1" != "$new_path" ] && mv "$1" "$new_path"
    echo "$new_path"
}

move_mail_to_cur() {
    #$1 = path to mail
    parent="$(dirname "$(dirname "$1")")"
    mail="$(basename "$1")"
    new_path="$parent/cur/$mail"
    [ "$(echo "$mail" | grep -o ":2,")" = "" ] && new_path="$new_path:2,"
    [ "$1" != "$new_path" ] && mv "$1" "$new_path"
    echo "$new_path"
}

get_mail_folders() {
    #$1 = folder to maildir top folder
    mdirs -a "$1"
}

move_mail_to_folder() {
    #$1 = path to mail
    #$2 = folder
    #$3 = folder to maildir top folder
    file_name="$(basename "$1")"
    new_path="$3/$2/new/$file_name"
    mv "$1" "$new_path"
    move_mail_to_cur "$new_path"
}
