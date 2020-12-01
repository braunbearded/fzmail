#!/bin/sh

. ./settings.sh

render_folder_content_short() {
    subject="$(mshow -n -q -h subject "$1" | cut -c 10-29)"
    date="$(date -d "$(mshow -n -q -h date "$1" | grep -oE "[0-9]+ [A-Z][a-z][a-z] [0-9][0-9][0-9][0-9] [0-9][0-9]:[0-9][0-9]")" +"%Y-%m-%d %H:%M")"
    from="$(mshow -n -q -h from "$1" | cut -c 7-)"
    flags="$(echo "$1" | grep -oE "2$flag_delimiter.*" | cut -c 3-)"
    if [ "$(echo "$flags" | grep -o "S")" = "" ]; then
        flags="${flags}U"
    fi
    # printf "%-6s|%-3s|%-25s|%-6s|%-6s|%-8s|%s|%-20s|%-20s\n" "$flags" "$date" "$subject" "$from" >> "$tmpcontent"
    printf "Flags: %-5s     Subject: %s\nDate: %s From: %s\n%s\n"  "$flags" "$subject" "$date" "$from" "$fzf_pre_folder_header"
}
