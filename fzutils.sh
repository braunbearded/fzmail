#!/bin/sh

#S=1
#U=2
#D=3
#T=4
#P=5
#R=6
#F=7
#Z=8"
#Y=9

mail_operations="read_editor|read in editor
read_browser|read in browser
mark_read|mark as read=1
mark_unread|mark as unread=2
reply|reply=34
trash|move to trash=4
move|move to folder=3
download_attachments|download attachment(s)=9
forward|forward=3
delete|delete=4
edit|edit
exit|exit"

convert_flags() {
    #$1 = flags
    flags="$1"
    [ "$(echo "$flags" | grep -o "U")" = "" ] && flags="S${flags}"
    [ "$(echo "$flags" | grep -o "D")" = "" ] && flags="Z${flags}"
    [ "$(echo "$flags" | grep -o "A")" = "" ] && flags="Y${flags}"
    echo "$flags" | tr "SUDTPRFZY" "123456789"
}

boundary_generator() {
    head /dev/urandom | tr -dc a-z0-9 | head -c 25
}

remove_empty_lines() {
    sed "/^[[:space:]]*$/d"
}

filter_operations() {
    #$1 = flags
    flags_regex="$(echo "$1" | awk '{print $1}' | grep -o . | \
        awk '{output = $1 "|" output} END {print "(" substr(output, 1, length(output)-1) ")"}')"
    echo "$mail_operations" | grep -vE "$flags_regex" | cut -d "=" -f 1
}

fzf_add_list() {
    #$1 = path to recipients
    #$2 = prompt
    #$3 = preselected values, if any
    data="$(cat "$1" && echo "exit")"
    if [ "$3" != "" ]; then
        list="$3, "
        multiline_list="$(echo "$list" | sed "s/,/\n/g" | awk '{$1=$1;print}')\n$data"
        options="$(echo "$multiline_list" | sort | uniq -u)"
    else
        options="$data"
    fi

    while [ "$options" != "exit" ]; do
        options="$(echo "$options" | remove_empty_lines)"
        selected="$(echo "$options" | fzf --prompt "$2(${list%??})")"
        [ "$selected" = "exit" ] || [ "$selected" = "" ] && { options="exit"; continue; }
        list="$selected, $list"
        multiline_list="$(echo "$list" | sed "s/,/\n/g" | awk '{$1=$1;print}')$nl$data"
        options="$(echo "$multiline_list" | sort | uniq -u | remove_empty_lines)"
    done
    echo "${list%??}"
}

get_profile_path_by_profile() {
    #$1 = path to cache
    #$2 = profile id

    profile_row="$(cut -d "|" -f 1 "$1/profiles" | grep -Fn "$2" | cut -d ":" -f 1)"
    sed "$profile_row!d" "$1/profiles" | cut -d "|" -f "3"
}

get_draft_by_profile() {
    #$1 = path to cache
    #$2 = profile id

    profile_row="$(cut -d "|" -f 1 "$1/profiles" | grep -Fn "$2" | cut -d ":" -f 1)"
    profile_path="$(get_profile_path_by_profile "$1" "$2")"
    profile_draft="$(sed "$profile_row!d" "$1/profiles" | cut -d "|" -f "5")"
    echo "$profile_path/$profile_draft"
}

get_trash_by_profile() {
    #$1 = path to cache
    #$2 = profile id

    profile_row="$(cut -d "|" -f 1 "$1/profiles" | grep -Fn "$2" | cut -d ":" -f 1)"
    profile_path="$(get_profile_path_by_profile "$1" "$2")"
    profile_trash="$(sed "$profile_row!d" "$1/profiles" | cut -d "|" -f "4")"
    echo "$profile_path/$profile_trash"
}

get_sender_by_profile() {
    #$1 = path to cache
    #$2 = profile id

    profile_row="$(cut -d "|" -f 1 "$1/profiles" | grep -Fn "$2" | cut -d ":" -f 1)"
    sed "$profile_row!d" "$1/profiles" | cut -d "|" -f "2"
}

get_attachments_by_profile() {
    #$1 = path to cache
    #$2 = profile id

    profile_row="$(cut -d "|" -f 1 "$1/profiles" | grep -Fn "$2" | cut -d ":" -f 1)"
    sed "$profile_row!d" "$1/profiles" | cut -d "|" -f "6"
}

new_draft() {
    #$1 = path to cache
    #$2 = profile id

    from="$(get_sender_by_profile "$1" "$2")"
    to="$(fzf_add_list "$1/$2/recipients" "To :")"
    cc="$(fzf_add_list "$1/$2/recipients" "Cc :")"
    bcc="$(fzf_add_list "$1/$2/recipients" "Bcc :")"
    profile_draft="$(get_draft_by_profile "$1" "$2")"
    ./generate-mail.sh "new" "$profile_draft" -f "$from" -t "$to" -c "$cc" -b "$bcc" -l "D"
}

send_new_mail() {
    #$1 = path to draft

    tmp_file="$1$(date +%s)"
    cp "$1" "$tmp_file" && ./convert-mail.sh "new" "$tmp_file" > "$1" && \
        rm "$tmp_file" && msmtp --read-envelope-from -t < "$1" && rm "$1"
}

send_reply_mail() {
    #$1 = path to draft

    tmp_file="$1$(date +%s)"
    cp "$1" "$tmp_file" && ./convert-mail.sh "reply" "$tmp_file" > "$1" && \
        rm "$tmp_file" && msmtp --read-envelope-from -t < "$1" && rm "$1"
}


edit_draft() {
    #$1 = path to cache
    #$2 = profile id
    #$3 = path to orig mail

    orig_from="$(echo "$3" | mshow -q -h from | cut -c 7-)"
    orig_cc="$(echo "$3" | mshow -q -h cc | cut -c 5-)"
    orig_bcc="$(echo "$3" | mshow -q -h bcc | cut -c 6-)"
    orig_from_header="$(echo "Old-From: $orig_from")"

    from="$(get_sender_by_profile "$1" "$2")"
    to="$(fzf_add_list "$1/$2/recipients" "Reply to: " "$orig_from")"
    cc="$(fzf_add_list "$1/$2/recipients" "Reply cc: " "$orig_cc")"
    bcc="$(fzf_add_list "$1/$2/recipients" "Reply bcc: " "$orig_bcc")"
    profile_draft="$(get_draft_by_profile "$1" "$2")"
    ./generate-mail.sh "reply" "$profile_draft" "$3" -f "$from" -t "$to" -c "$cc" -b "$bcc" -l "D" -h "$orig_from_header"
}

move_to_trash() {
    #$1 = path to cache
    #$2 = profile id
    #$3 = path to mail

    trash_folder="$(get_trash_by_profile "$1" "$2")"
    profile_path="$(get_profile_path_by_profile "$1" "$2")"
    new_path="$(./fzmaildir.sh "move_mail" "$3" "$trash_folder" "$profile_path")"
    ./fzmaildir.sh "set_flag" "$new_path" "T" > /dev/null
}

move_to_folder() {
    #$1 = path to cache
    #$2 = profile id
    #$3 = folder id
    #$4 = path to mail

    profile_path="$(get_profile_path_by_profile "$1" "$2")"
    new_path="$(./fzmaildir.sh "move_mail" "$4" "$3" "$profile_path")"
    ./fzmaildir.sh "set_flag" "$new_path" "T" > /dev/null
}

[ "$1" = "convert_flags" ] && convert_flags "$2"
[ "$1" = "filter_operations" ] && filter_operations "$2"
[ "$1" = "new_draft" ] && new_draft "$2" "$3"
[ "$1" = "edit_draft" ] && edit_draft "$2" "$3" "$4"
[ "$1" = "send_new" ] && send_new_mail "$2"
[ "$1" = "send_reply" ] && send_new_mail "$2"
[ "$1" = "draft_path" ] && get_draft_by_profile "$2" "$3"
[ "$1" = "trash" ] && move_to_trash "$2" "$3" "$4"
