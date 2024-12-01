#!/bin/sh

get_recipients() {
    #$1 = path maildir

    find "$1" -type f ! -name '.*' | maddr | sort -u
}

get_attachments() {
    #$1 = path to attachment

    mkdir -p "$1"
    find "$1" -type f ! -name '.*'
}

trim() {
    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

clear_cache() {
    [ ! -d "$1" ] && exit
    [ -d "${1}_last" ] && rm -rf "${1}_backup"
    mv "$1" "${1}_backup"
}

update_cache_flag() {
    # $1 = path to cache
    # $2 = profile_id
    # $3 = folder_id
    # $4 = mail_id
    # $5 = mail path

    max_flag_length="$(./fzcache.sh "get_flag_length" "$1")"
    flags="U$(echo "$5" | grep -oE "2,.*" | cut -c 3-)";
    [ "$(echo "$flags" | grep -o "S")" != "" ] && flags="$(echo "$flags" | tr -d "U" | tr -d "S")";
    attachment="$(grep -o "Content-Disposition: attachment;" "$5")"
    [ "$attachment" != "" ] && flags="${flags}A";
    new_flag_length="$(echo "$flags" | wc -L)"

    if [ "$new_flag_length" -gt "$max_flag_length" ]; then
        #TODO delete rendered views
        sed -i "s/flag_length.*/flag_length\|$new_flag_length/"
    fi

    cache_file="$1/$2/$3/formated_mails"
    mail_id="$(basename "$5" | cut -d "," -f 1,2)";
    subject="$(mshow -q -h subject "$5" | cut -d ":" -f 2 | trim | tr "\n" " " )";
    date="$(mshow -q -h date "$5" | cut -d ":" -f 2 | trim)"
    from="$(mshow -q -h from "$5" | cut -d ":" -f 2 | trim)";

    target_row="$(grep -Fc "$4" "$cache_file" | cut -d ":" -f 1)"

    [ "$target_row" -gt 1 ] && head -n "$((target_row - 1))" "$5" > "${cache_file}_tmp"
    printf "%s|%s|%s|%s|%s|%s\n" "$mail_id" "$5" "$flags" "$date" "$from" \
        "$subject" >> "${cache_file}_tmp"
    tail -n +"$((target_row + 1))" "$cache_file" >> "${cache_file}_tmp"
    rm "$cache_file"
    mv "${cache_file}_tmp" "$cache_file"
}

get_field_length() {
    grep -E "^$1" "$2/max_field_lengths" | cut -d "|" -f 2
}

init_cache() {
    #$1 = cache destination
    #$2 = path to profile config

    [ -d "$1" ] && rm -rf "$1"
    mkdir "$1"
    cp "$2" "$1/profiles"

    max_id_length="$(while read -r profile_line; do profile_path="$(echo "$profile_line" | cut -d "|" -f 3)"; find "$profile_path" -type f ! -name ".uidvalidity" ! -name ".mbsyncstate"; done < "$2" | wc -l | wc -L)"
    max_profile_id_length="$(cut -d "|" -f 1 "$2" | wc -L)"
    max_folder_length="$(while read -r profile_line; do profile_path="$(echo "$profile_line" | cut -d "|" -f 3)"; profile_path_length="$(echo "$profile_path" | wc -L)"; find "$profile_path" -type d -name "new" | cut -c "$((profile_path_length + 2))"- | rev | cut -c 5-; done < "$2" | wc -L)"
    max_flag_length="$(while read -r profile_line; do profile_path="$(echo "$profile_line" | cut -d "|" -f 3)"; find "$profile_path" -type f ! -name ".uidvalidity" ! -name ".mbsyncstate" | cut -d "," -f 3; done < "$2" | wc -L)"
    max_from_length="20"
    max_date_length="16"
    max_entry_length=100 # TODO
    max_entry_length="$((max_profile_id_length + max_profile_id_length + \
        max_id_length + max_folder_length + max_flag_length + \
        max_folder_id_length + max_subject_length + max_from_length + \
        max_date_length + 12))"
    max_subject_length="20"

    while read -r profile_line; do
        profile_id="$(echo "$profile_line" | awk -F "|" '{print $1}')";
        profile_path="$(echo "$profile_line" | awk -F "|" '{print $3}')";
        profile_path_length="$(echo "$profile_path" | wc -L)"
        profile_attachments="$(echo "$profile_line" | awk -F "|" '{print $6}')";

        cache_profile_path="$1/$profile_id"
        mkdir -p "$cache_profile_path"

        find "$profile_path" -type d -name "*new" | \
            awk -v profile_path_length="$profile_path_length" \
            '{short_folder=substr($0, profile_path_length + 2); printf "%s|%s\n", substr($0, 0, length($0) - 4), substr(short_folder, 0, length(short_folder) - 4)}' > "$cache_profile_path/profile_folders"

        while read -r folder; do
            folder_id="$(echo "$folder" | cut -d "|" -f 2)"
            mkdir -p "$cache_profile_path/$folder_id"

            find "$profile_path/$folder_id" -type f ! -name ".uidvalidity" \
                ! -name ".mbsyncstate" > "$cache_profile_path/$folder_id/mails"

            while read -r mail; do
                mail_id="$(basename "$mail" | cut -d "," -f 1,2)";
                subject="$(mshow -q -h subject "$mail" | cut -d ":" -f 2 | trim | tr "\n" " " | head -c "$max_subject_length")";
                date="$(mshow -q -h date "$mail" | cut -d ":" -f 2 | trim)"
                from="$(mshow -q -h from "$mail" | cut -d ":" -f 2 | trim)";
                flags="U$(echo "$mail" | grep -oE "2,.*" | cut -c 3-)";
                [ "$(echo "$flags" | grep -o "S")" != "" ] && flags="$(echo "$flags" | tr -d "U" | tr -d "S")";
                attachment="$(grep -o "Content-Disposition: attachment;" "$mail")"
                [ "$attachment" != "" ] && flags="${flags}A";
                printf "%s|%s|%s|%s|%s|%s\n" "$mail_id" "$mail" \
                    "$flags" "$date" "$from" "$subject" >> \
                    "$cache_profile_path/$folder_id/formated_mails"
            done < "$cache_profile_path/$folder_id/mails" &
        done < "$cache_profile_path/profile_folders" &
        get_recipients "$profile_path" > "$cache_profile_path/recipients" &
        get_attachments "$profile_attachments" > "$cache_profile_path/attachment_cache" &
    done < "$2" &

    printf "%s|%s\n%s|%s\n%s|%s\n%s|%s\n%s|%s\n%s|%s\n%s|%s\n%s|%s\n" \
        "id_length" "$max_id_length" \
        "profile_id_length" "$max_profile_id_length" \
        "folder_length" "$max_folder_length" \
        "flag_length" "$max_flag_length" \
        "subject_length" "$max_subject_length" \
        "from_length" "$max_from_length" \
        "data_length" "$max_date_length" \
        "entry_length" "$max_entry_length" > "$1/max_field_lengths"
}

update_folder() {
    #$1 = cache destination
    #$2 = path to profile config
    #$3 = profile id
    #$4 = folder id
    [ -f "$1/$3/$4/formated_mails" ] && rm "$1/$3/$4/formated_mails"

    max_id_length="$(while read -r profile_line; do profile_path="$(echo "$profile_line" | cut -d "|" -f 3)"; find "$profile_path" -type f ! -name ".uidvalidity" ! -name ".mbsyncstate"; done < "$2" | wc -l | wc -L)"
    max_profile_id_length="$(cut -d "|" -f 1 "$2" | wc -L)"
    max_folder_length="$(while read -r profile_line; do profile_path="$(echo "$profile_line" | cut -d "|" -f 3)"; profile_path_length="$(echo "$profile_path" | wc -L)"; find "$profile_path" -type d -name "new" | cut -c "$((profile_path_length + 2))"- | rev | cut -c 5-; done < "$2" | wc -L)"
    max_flag_length="$(while read -r profile_line; do profile_path="$(echo "$profile_line" | cut -d "|" -f 3)"; find "$profile_path" -type f ! -name ".uidvalidity" ! -name ".mbsyncstate" | cut -d "," -f 3; done < "$2" | wc -L)"
    max_from_length="20"
    max_date_length="16"
    max_entry_length=100 # TODO
    max_entry_length="$((max_profile_id_length + max_profile_id_length + \
        max_id_length + max_folder_length + max_flag_length + \
        max_folder_id_length + max_subject_length + max_from_length + \
        max_date_length + 12))"
    max_subject_length="20"

    while read -r profile_line; do
        profile_id="$(echo "$profile_line" | awk -F "|" '{print $1}')";
        [ "$profile_id" != "$3" ] && continue
        profile_path="$(echo "$profile_line" | awk -F "|" '{print $3}')";
        profile_path_length="$(echo "$profile_path" | wc -L)"
        profile_attachments="$(echo "$profile_line" | awk -F "|" '{print $6}')";

        cache_profile_path="$1/$profile_id"
        mkdir -p "$cache_profile_path"

        find "$profile_path" -type d -name "*new" | \
            awk -v profile_path_length="$profile_path_length" \
            '{short_folder=substr($0, profile_path_length + 2); printf "%s|%s\n", substr($0, 0, length($0) - 4), substr(short_folder, 0, length(short_folder) - 4)}' > "$cache_profile_path/profile_folders"

        while read -r folder; do
            folder_id="$(echo "$folder" | cut -d "|" -f 2)"
            [ "$folder_id" != "$4" ] && continue
            mkdir -p "$cache_profile_path/$folder_id"

            find "$profile_path/$folder_id" -type f ! -name ".uidvalidity" \
                ! -name ".mbsyncstate" > "$cache_profile_path/$folder_id/mails"

            while read -r mail; do
                mail_id="$(basename "$mail" | cut -d "," -f 1,2)";
                subject="$(mshow -q -h subject "$mail" | cut -d ":" -f 2 | trim | tr "\n" " " | head -c "$max_subject_length")";
                date="$(mshow -q -h date "$mail" | cut -d ":" -f 2 | trim)"
                from="$(mshow -q -h from "$mail" | cut -d ":" -f 2 | trim)";
                flags="U$(echo "$mail" | grep -oE "2,.*" | cut -c 3-)";
                [ "$(echo "$flags" | grep -o "S")" != "" ] && flags="$(echo "$flags" | tr -d "U" | tr -d "S")";
                attachment="$(grep -o "Content-Disposition: attachment;" "$mail")"
                [ "$attachment" != "" ] && flags="${flags}A";
                printf "%s|%s|%s|%s|%s|%s\n" "$mail_id" "$mail" \
                    "$flags" "$date" "$from" "$subject" >> \
                    "$cache_profile_path/$folder_id/formated_mails"
            done < "$cache_profile_path/$folder_id/mails" &
        done < "$cache_profile_path/profile_folders" &
        get_recipients "$profile_path" > "$cache_profile_path/recipients" &
        get_attachments "$profile_attachments" > "$cache_profile_path/attachment_cache" &
    done < "$2" &

    printf "%s|%s\n%s|%s\n%s|%s\n%s|%s\n%s|%s\n%s|%s\n%s|%s\n%s|%s\n" \
        "id_length" "$max_id_length" \
        "profile_id_length" "$max_profile_id_length" \
        "folder_length" "$max_folder_length" \
        "flag_length" "$max_flag_length" \
        "subject_length" "$max_subject_length" \
        "from_length" "$max_from_length" \
        "data_length" "$max_date_length" \
        "entry_length" "$max_entry_length" > "$1/max_field_lengths"
}

[ "$1" = "clear" ] && clear_cache "$2"
[ "$1" = "init" ] && init_cache "$2" "$3"
# [ "$1" = "update_flag" ] && update_cache_flag "$2" "$3" "$4" "$5" "$6" "$7" # not really needed anymore
[ "$1" = "get_id_length" ] && get_field_length "id_length" "$2"
[ "$1" = "get_profile_id_length" ] && get_field_length "profile_id_length" "$2"
[ "$1" = "get_folder_length" ] && get_field_length "folder_length" "$2"
[ "$1" = "get_flag_length" ] && get_field_length "flag_length" "$2"
[ "$1" = "get_subject_length" ] && get_field_length "subject_length" "$2"
[ "$1" = "get_from_length" ] && get_field_length "from_length" "$2"
[ "$1" = "get_date_length" ] && get_field_length "data_length" "$2"
[ "$1" = "get_entry_length" ] && get_field_length "entry_length" "$2"
[ "$1" = "update_folder" ] && update_folder "$2" "$3" "$4" "$5"
