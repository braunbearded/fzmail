#!/bin/sh

get_sender_by_profile() {
    #$1 = path to profile
    #$2 = profile id
    sed "$2!d" "$1" | awk -F "|" '{print $3}'
}

get_mails_by_profile() {
    #$1 = path to config
    #$2 = profile id
    #$3 = folder
    mail_path="$(sed "$2!d" "$1" | awk -F "|" '{print $4}')"
    mail_path_folder="$mail_path/$3"
    [ ! -d "$mail_path_folder" ] && mail_path_folder="$(find "$mail_path" -type d | \
        grep -Ev "(/cur$|/new$|/tmp$)" | grep -F "$3" | head -n 1)"
    mlist "$mail_path_folder"
}

get_path_by_profile() {
    #$1 = path to config
    #$2 = profile id
    sed "$2!d" "$1" | awk -F "|" '{print $4}'
}

get_name_by_profile() {
    #$1 = path to config
    #$2 = profile id
    sed "$2!d" "$1" | awk -F "|" '{print $2}'
}

get_trash_by_profile() {
    #$1 = path to config
    #$2 = profile id
    sed "$2!d" "$1" | awk -F "|" '{print $5}'
}

get_draft_by_profile() {
    #$1 = path to config
    #$2 = profile id
    sed "$2!d" "$1" | awk -F "|" '{print $6}'
}

get_attachment_by_profile() {
    #$1 = path to config
    #$2 = profile id
    sed "$2!d" "$1" | awk -F "|" '{print $7}'
}
