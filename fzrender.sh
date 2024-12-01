#!/bin/sh

profile_operations="new_mail|<New mail>
list_attachments|<List attachment(s)>"

general_operations="rerender|<Rerender>
update_cache|<Update cache>
sync_imap|<Sync imap>
exit|<Exit>"

render_main() {
    #$1 = cache destination

    max_profile_id_length="$(./fzcache.sh "get_profile_id_length" "$1")"
    max_id_length="$(./fzcache.sh "get_id_length" "$1")"
    max_folder_length="$(./fzcache.sh "get_folder_length" "$1")"
    max_entry_length="$(./fzcache.sh "get_entry_length" "$1")"
    header_marker="$(printf "%*s" "$max_entry_length" " " | tr " " "-")"

    row_id=1
    while read -r profile_line; do
        profile_id="$(echo "$profile_line" | cut -d "|" -f 1)";
        profile_draft_id="$(echo "$profile_line" | cut -d "|" -f 5)";
        cache_profile_path="$1/$profile_id"
        pre_content="header|$profile_id|||"

        printf "%s|%s\n" "$pre_content" "$header_marker"
        printf "%s|%-*s|%-*s\n" "$pre_content" "$max_id_length" "$row_id" \
            "$max_profile_id_length" "$profile_id"
        printf "%s|%s\n" "$pre_content" "$header_marker"

        row_id="$((row_id + 1))"
        while read -r folder; do
            folder_long="$(echo "$folder" | cut -d "|" -f 1)"
            folder_short="$(echo "$folder" | cut -d "|" -f 2)"
            pre_content="folder|$profile_id|$folder_short||$folder_long"

            printf "%s|%-*s|%-*s|%-*s\n" "$pre_content" \
                "$max_id_length" "$row_id" "$max_profile_id_length" \
                "$profile_id" "$max_folder_length" "$folder_short"

            row_id="$((row_id + 1))"
        done < "$cache_profile_path/profile_folders"

        pre_content="header|$profile_id|||"
        printf "%s|%s\n" "$pre_content" "$header_marker"
        for index in $(seq 1 "$(echo "$profile_operations" | wc -l)"); do
            header_type="$(echo "$profile_operations" | sed "$index!d" | cut -d "|" -f 1)"
            header_text="$(echo "$profile_operations" | sed "$index!d" | cut -d "|" -f 2)"
            folder_id=""
            [ "$header_type" = "new_mail" ] && folder_id="$profile_draft_id"
            pre_content="$header_type|$profile_id|$folder_id||"

            printf "%s|%-*s|%-*s|%s\n" "$pre_content" \
                "$max_id_length" "$row_id" "$max_profile_id_length" \
                "$profile_id" "$header_text"
            row_id="$((row_id + 1))"
        done
    done < "$1/profiles"

    pre_content="header||||"
    printf "%s|%s\n" "$pre_content" "$header_marker"
    for index in $(seq 1 "$(echo "$general_operations" | wc -l)"); do
        header_type="$(echo "$general_operations" | sed "$index!d" | cut -d "|" -f 1)"
        header_text="$(echo "$general_operations" | sed "$index!d" | cut -d "|" -f 2)"
        pre_content="$header_type||||"

        printf "%s|%-*s|%s\n" "$pre_content" \
            "$max_id_length" "$row_id" "$header_text"
        row_id="$((row_id + 1))"
    done
}

render_view() {
    #$1 = folder
    #$2 = path to cache

    folder="$(dirname "$2/$1")"
    [ ! -d "$folder" ] || [ "$folder" = "." ]  && echo "main||||No mails here" && exit
    profile_id="$(echo "$folder" | cut -d "/" -f 3)"
    folder_id="$(echo "$folder" | cut -d "/" -f 4-)"

    row_id=1
    while read -r mail; do
        mail_id="$(echo "$mail" | cut -d "|" -f 1)"
        mail_path="$(echo "$mail" | cut -d "|" -f 2)"
        flags="$(echo "$mail" | cut -d "|" -f 3)"
        max_flag_length="$(./fzcache.sh "get_flag_length" "$2")"
        max_date_length="$(./fzcache.sh "get_date_length" "$2")"
        date="$(echo "$mail" | cut -d "|" -f 4 | cut -c -"$max_date_length")"
        max_from_length="$(./fzcache.sh "get_from_length" "$2")"
        from="$(echo "$mail" | cut -d "|" -f 5 | cut -c -"$max_from_length")"
        max_subject_length="$(./fzcache.sh "get_subject_length" "$2")"
        subject="$(echo "$mail" | cut -d "|" -f 6 | cut -c -"$max_subject_length")"
        max_subject_length="$(./fzcache.sh "get_subject_length" "$2")"

        pre_content="mail|$profile_id|$folder_id|$mail_id|$mail_path"
        printf "%s|%-*s|%-*s|%-*s|%-*s\n" "$pre_content" "$max_flag_length" "$flags" \
            "$max_date_length" "$date" "$max_from_length" "$from" \
            "$max_subject_length" "$subject"
        row_id="$((row_id + 1))"
    done < "$2/$profile_id/$folder_id/formated_mails"

}

render_fzf_preview() {
    #$1 = entry
    #$2 = path to cache
    max_entry_length="$(./fzcache.sh "get_entry_length" "$2")"
    header_marker="$(printf "%*s" "$max_entry_length" " " | tr " " "-")"

    entry_type="$(echo "$1" | cut -d "|" -f 1)"
    profile_id="$(echo "$1" | cut -d "|" -f 2)"
    folder_id="$(echo "$1" | cut -d "|" -f 3)"
    mail_id="$(echo "$1" | cut -d "|" -f 4)"
    entry_path="$(echo "$1" | cut -d "|" -f 5)"

    #TODO cache result?
    if [ "$entry_type" = "folder" ]; then
        folder_cache="$2/$profile_id/$folder_id/formated_mails"
        [ ! -f "$folder_cache" ] && echo "Folder is empty" && exit
        while read -r mail; do
            flags="$(echo "$mail" | cut -d "|" -f 3)"
            date="$(echo "$mail" | cut -d "|" -f 4)"
            from="$(echo "$mail" | cut -d "|" -f 5)"
            subject="$(echo "$mail" | cut -d "|" -f 6)"

            printf "Date: %s\nFrom: %s\nFlags: %s\nSubject: %s\n%s\n" "$date" \
                "$from" "$flags" "$subject" "$header_marker"
        done < "$folder_cache"
    fi

    if [ "$entry_type" = "mail" ]; then
        mshow -N -n -A "text/plain" "$entry_path"
    fi
}

render_header_main() {
    #$1 = path to cache

    max_profile_id_length="$(./fzcache.sh "get_profile_id_length" "$1")"
    profile="$(echo "Profile" | cut -c -"$max_profile_id_length")"

    max_id_length="$(./fzcache.sh "get_id_length" "$1")"
    id="$(echo "Row" | cut -c -"$max_id_length")"

    max_folder_length="$(./fzcache.sh "get_folder_length" "$1")"
    folder="$(echo "Folder" | cut -c -"$max_folder_length")"

    printf "%-*s|%-*s|%-*s" "$max_id_length" "$id" "$max_profile_id_length" \
        "$profile" "$max_folder_length" "$folder"
}

render_header_folder() {
    #$1 = path to cache

    max_flag_length="$(./fzcache.sh "get_flag_length" "$1")"
    flag="$(echo "Flag" | cut -c -"$max_flag_length")"

    max_date_length="$(./fzcache.sh "get_date_length" "$1")"
    date="$(echo "Date" | cut -c -"$max_date_length")"

    max_from_length="$(./fzcache.sh "get_from_length" "$1")"
    from="$(echo "From" | cut -c -"$max_from_length")"

    max_subject_length="$(./fzcache.sh "get_subject_length" "$1")"
    subject="$(echo "Subject" | cut -c -"$max_subject_length")"

    printf "%-*s|%-*s|%-*s|%-*s\n" "$max_flag_length" "$flag" \
        "$max_date_length" "$date" "$max_from_length" "$from" \
        "$max_subject_length" "$subject"
}

render_operations() {
    #$1 = path to cache
    #$2 = path to current mail

    mail="$(cat "$2")"
    profile_id="$(echo "$mail" | cut -d "|" -f 1)"
    folder_id="$(echo "$mail" | cut -d "|" -f 2)"
    mail_id="$(echo "$mail" | cut -d "|" -f 3)"

    while [ ! -f "$1/$profile_id/$folder_id/formated_mails" ]; do
        sleep 0.2
    done

    tail -f -n +1 "$1/$profile_id/$folder_id/formated_mails" | grep --line-buffered '.*' | while read -r formatted_line; do
        [ "$(echo "$formatted_line" | grep -Fo "$mail_id")" = "" ] && continue
        mail_path="$(echo "$formatted_line" | cut -d "|" -f 2)"
        flags="$(echo "$formatted_line" | cut -d "|" -f 3)"
        converted_flags="$(./fzutils.sh "convert_flags" "$flags")"
        ./fzutils.sh "filter_operations" "$converted_flags" | awk -F "|" \
            -v profile_id="$profile_id" -v folder_id="$folder_id" \
            -v mail_id="$mail_id" -v mail_path="$mail_path" \
            '{printf "%s|%s|%s|%s|%s|%s\n", $1, profile_id, folder_id, mail_id, \
            mail_path, $2}'
    done
}

render_clear() {
    #$1 = path to cache

    [ -f "$1/header_folder" ] && rm "$1/header_folder"
    [ -f "$1/header_main" ] && rm "$1/header_main"
    [ -f "$1/header_operation" ] && rm "$1/header_operation"
    [ -f "$1/history" ] && rm "$1/history"
    [ -f "$1/mail" ] && rm "$1/mail"
    [ -f "$1/main" ] && rm "$1/main"
    [ -f "$1/operations" ] && rm "$1/operations"
    find "$1" -type f -name "view" -delete
    find "$1" -type f -name "folders" -delete
}

render_attachments() {
    #$1 = view
    #$2 = cache path

    profile_id="$(echo "$1" | cut -d "/" -f 1)"
    cat "$2/$profile_id/attachment_cache"
    echo "exit_attachment|||||Exit"
}

render_move() {
    #$1 = path to cache
    #$2 = path to current mail

    mail="$(cat "$2")"
    profile_id="$(echo "$mail" | cut -d "|" -f 1)"
    mail_id="$(echo "$mail" | cut -d "|" -f 3)"
    mail_path="$(echo "$mail" | cut -d "|" -f 4)"

    while read -r folder; do
        folder_id="$(echo "$folder" | cut -d "|" -f 2)"
        pre_content="move_folder|$profile_id|$folder_id|$mail_id|$mail_path"
            printf "%s|%*s\n" "$pre_content" "$folder_id"
    done < "$1/$profile_id/profile_folders"

}

[ "$1" = "view" ] && [ "$2" = "main" ] && render_main "$4"
[ "$1" = "view" ] && [ "$2" = "operations" ] && render_operations "$4" "$5"
[ "$1" = "view" ] && [ "$3" = "attachment" ] && render_attachments "$2" "$4"
[ "$1" = "view" ] && [ "$3" = "folder" ] && render_view "$2" "$4"
[ "$1" = "view" ] && [ "$3" = "folders" ] && render_move "$4" "$5"
[ "$1" = "header" ] && [ "$2" = "main" ] && render_header_main "$3"
[ "$1" = "header" ] && [ "$2" = "folder" ] && render_header_folder "$3"
[ "$1" = "fzf_header" ] && render_fzf_header "$2" "$3"
[ "$1" = "preview" ] && render_fzf_preview "$2" "$3"
[ "$1" = "clear" ] && render_clear "$2"
