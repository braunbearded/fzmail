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
    mail_path="$(sed "$2!d" "$1" | awk -F "|" '{print $4}')/$3"
    mlist "$mail_path"
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
