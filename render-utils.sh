#!/bin/sh

. ./settings.sh
. ./profile-utils.sh

date_regex="[0-9]+ [A-Z][a-z][a-z] [0-9][0-9][0-9][0-9] [0-9][0-9]:[0-9][0-9]"

render_folder_content_short() {
    subject="$(mshow -n -q -h subject "$1" | cut -c 10-29)"
    date="$(date -d "$(mshow -n -q -h date "$1" | grep -oE "$date_regex")" \
        +"%Y-%m-%d %H:%M")"
    from="$(mshow -n -q -h from "$1" | cut -c 7-)"
    flags="$(echo "$1" | grep -oE "2$flag_delimiter.*" | cut -c 3-)"
    if [ "$(echo "$flags" | grep -o "S")" = "" ]; then
        flags="${flags}U"
    fi

    printf "Flags: %-5s     Subject: %s\nDate: %s From: %s\n%s\n"  \
        "$flags" "$subject" "$date" "$from" "$fzf_pre_folder_header"
}

render_folder_content() {
    #$1 = path to config
    #$2 = profile id
    #$3 = folder
    mails_folder="$(get_mails_by_profile "$1" "$2" "$3")"
    echo "$mails_folder" | xargs -I "__" sh -c \
        'subject="$(mshow -n -q -h subject "__" | cut -c 10-29)";
        date="$(date -d "$(mshow -n -q -h date "__" |
            grep -oE "[0-9]+ [A-Z][a-z][a-z] [0-9][0-9][0-9][0-9] [0-9][0-9]:[0-9][0-9]")" +"%Y-%m-%d %H:%M")";
        from="$(mshow -n -q -h from "__" | cut -c 7-)";
        attachment="$(grep -o "Content-Disposition: attachment; filename=" "__")"
        flags="$(echo "__" | grep -oE "2,.*" | cut -c 3-)";
        [ "$(echo "$flags" | grep -o "S")" = "" ] && flags="${flags}U";
        [ "$attachment" != "" ] && flags="${flags}A";
        printf "%s|%s|%s|%s\n" "$flags" "$date" "$subject" "$from"' | \
            awk -F "|" 'BEGIN {i = 1} {printf "%-6s|%-3s|%s|%s|%-6s|%-8s|%s|%-20s|%-20s\n",
                    "ROW_PL", "PPL", "PROFILE_NAME_PL", "FOIDPL", i++, $1, $2, $3, $4}'
}

trim() {
    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

init_cache() {
    #$1 = path to profile
    #$2 = cache destination

    max_profile_id_length="$(cut -d "|" -f 1 "$1" | wc -L)"
    max_profile_name_length="$(cut -d "|" -f 2 "$1" | wc -L)"
    max_id_length="$(while read -r profile_line; do profile_path="$(echo "$profile_line" | cut -d "|" -f 4)"; find "$profile_path" -type f ! -name ".uidvalidity" ! -name ".mbsyncstate"; done < "$1" | wc -l | wc -L)"
    max_folder_length="$(while read -r profile_line; do profile_path="$(echo "$profile_line" | cut -d "|" -f 4)"; profile_path_length="$(echo "$profile_path" | wc -L)"; find "$profile_path" -type d -name "new" | cut -c "$((profile_path_length + 2))"- | rev | cut -c 5-; done < "$1" | wc -L)"
    max_flag_length="$(while read -r profile_line; do profile_path="$(echo "$profile_line" | cut -d "|" -f 4)"; find "$profile_path" -type f ! -name ".uidvalidity" ! -name ".mbsyncstate" | cut -d "," -f 3; done < "$1" | wc -L)"
    max_folder_id_length="$(while read -r profile_line; do profile_path="$(echo "$profile_line" | cut -d "|" -f 4)"; find "$profile_path" -type d; done < "$1" | wc -l | wc -L)"
    max_subject_length="20"
    max_from_length="20"
    max_date_length="10"
    max_entry_length="$((max_profile_id_length + max_profile_id_length + \
        max_id_length + max_folder_length + max_flag_length + \
        max_folder_id_length + max_subject_length + max_from_length + \
        max_date_length + 12))"

    printf "%s|%s|%s|%s|%s|%s|%s|%s" "$max_profile_id_length" "$max_profile_name_length" \
        "$max_id_length" "$max_folder_length" "$max_flag_length" \
        "$max_folder_id_length" "$max_entry_length" "$max_date_length" > "$2/max_field_lengths"

    while read -r profile_line; do
        profile_id="$(echo "$profile_line" | awk -F "|" '{print $1}')";
        profile_path="$(echo "$profile_line" | awk -F "|" '{print $4}')";
        profile_path_length="$(echo "$profile_path" | wc -L)"
        profile_name="$(echo "$profile_line" | awk -F "|" '{print $2}')";

        cache_profile_path="$2/$profile_id"
        mkdir -p "$cache_profile_path"
        [ -f "$cache_profile_path/selected_folders" ] && rm "$cache_profile_path/selected_folders"
        touch "$cache_profile_path/selected_folders"

        find "$profile_path" -type d | grep "new" | sort | \
            awk -v profile_path_length="$profile_path_length" \
            '{short_folder=substr($0, profile_path_length + 2); printf "%s|%s\n", substr($0, 0, length($0) - 4), substr(short_folder, 0, length(short_folder) - 4)}' > "$cache_profile_path/profile_folders"

        folder_id=1
        while read -r folder; do
            folder_short="$(echo "$folder" | cut -d "|" -f 2)"
            max_mail_id_length="$(find "$profile_path/$folder_short" -type f ! -name ".uidvalidity" ! -name ".mbsyncstate" | wc -l | wc -L)"
            mkdir -p "$cache_profile_path/$folder_id"
            mail_id=1

            find "$profile_path/$folder_short" -type f ! -name ".uidvalidity" ! -name ".mbsyncstate" | sort > "$cache_profile_path/$folder_id/mails"
            folder_padding_length="$((max_folder_length - max_folder_id_length - max_mail_id_length - max_flag_length - max_date_length - 4))"
            while read -r mail; do
                subject="$(mshow -q -h subject "$mail" | cut -d ":" -f 2 | trim | cut -c -"$max_subject_length")";
                date="$(mshow -q -h date "$mail" | cut -d ":" -f 2 | trim | cut -c -"$max_date_length")"
                from="$(mshow -q -h from "$mail" | cut -d ":" -f 2 | trim | cut -c -"$max_from_length")";
                flags="U$(echo "$mail" | grep -oE "2,.*" | cut -c 3-)";
                [ "$(echo "$flags" | grep -o "S")" != "" ] && flags="$(echo "$flags" | tr -d "U" | tr -d "S")";
                attachment="$(grep -o "Content-Disposition: attachment;" "$mail")"
                [ "$attachment" != "" ] && flags="${flags}A";
                printf "%-*s|%-*s|%-*s|%-*s|%-*s|%-*s|%-*s|%-*s|%-*s|%-*s\n" \
                    "$max_id_length" "R" "$max_profile_id_length" "$profile_id" \
                    "$max_profile_name_length" "$profile_name" "$folder_padding_length" " "\
                    "$max_folder_id_length" "$folder_id" "$max_mail_id_length" \
                    "$mail_id" "$max_flag_length" "$flags" "$max_date_length" \
                    "$date" "$max_from_length" "$from" "$max_subject_length" \
                    "$subject" >> "$cache_profile_path/$folder_id/formated_mails"
                mail_id="$((mail_id + 1))"
            done < "$cache_profile_path/$folder_id/mails"
            folder_id="$((folder_id + 1))"
        done < "$cache_profile_path/profile_folders"
    done < "$1"

}

render() {
    #$1 = path to profile
    #$2 = cache destination

    max_profile_id_length="$(cut -d "|" -f 1 "$2/max_field_lengths")"
    max_profile_name_length="$(cut -d "|" -f 2 "$2/max_field_lengths")"
    max_id_length="$(cut -d "|" -f 3 "$2/max_field_lengths")"
    max_folder_length="$(cut -d "|" -f 4 "$2/max_field_lengths")"
    max_entry_length="$(cut -d "|" -f 7 "$2/max_field_lengths")"
    header_marker="$(printf "%*s" "$max_entry_length" " " | tr " " "-")"
    row_id_place_padding="$(printf "%*s" "$((max_id_length - 1))" " ")"

    row_id=1
    while read -r profile_line; do
        profile_id="$(echo "$profile_line" | awk -F "|" '{print $1}')";
        profile_name="$(echo "$profile_line" | awk -F "|" '{print $2}')";
        cache_profile_path="$2/$profile_id"
        folder_id=1

        printf "%s\n" "$header_marker"
        printf "%-*s|%-*s|%-*s\n" "$max_id_length" "$row_id" \
            "$max_profile_id_length" "$profile_id" "$max_profile_name_length" \
            "$profile_name"
        printf "%s\n" "$header_marker"

        row_id="$((row_id + 1))"
        while read -r folder; do
            folder_short="$(echo "$folder" | cut -d "|" -f 2)"
            printf "%-*s|%-*s|%-*s|%-*s|\n" "$max_id_length" "$row_id" \
                "$max_profile_id_length" "$profile_id" "$max_profile_name_length" \
                "$profile_name" "$max_folder_length" "$folder_short"
            row_id="$((row_id + 1))"
            if [ "$(grep -oE "^$folder_short$" "$cache_profile_path/selected_folders")" != "" ]; then
                while read -r mail; do
                    echo "$mail" | sed "s/R$row_id_place_padding/$(printf "%*s" "$max_id_length" "$row_id")/"
                    row_id="$((row_id + 1))"
                done < "cache_profile_path/$folder_id/formated_mails"
            fi
            folder_id="$((folder_id + 1))"
        done < "$cache_profile_path/profile_folders"
    done < "$1"
}

render_tree2() {
    max_profile_id_length="$(cut -d "|" -f 1 "$2/max_field_lengths")"
    max_profile_name_length="$(cut -d "|" -f 2 "$2/max_field_lengths")"
    max_id_length="$(cut -d "|" -f 3 "$2/max_field_lengths")"
    max_folder_length="$(cut -d "|" -f 4 "$2/max_field_lengths")"
    max_entry_length="$(cut -d "|" -f 7 "$2/max_field_lengths")"
    header_marker="$(printf "%*s" "$max_entry_length" " " | tr " " "-")"
    row_id_place_padding="$(printf "%*s" "$((max_id_length - 1))" " ")"

    row_id=1
    while read -r profile_line; do
        profile_id="$(echo "$profile_line" | awk -F "|" '{print $1}')";
        profile_name="$(echo "$profile_line" | awk -F "|" '{print $2}')";
        folder_id=1

        printf "%s\n" "$header_marker"
        printf "%-*s|%-*s|%-*s\n" "$max_id_length" "$row_id" \
            "$max_profile_id_length" "$profile_id" "$max_profile_name_length" \
            "$profile_name"
        printf "%s\n" "$header_marker"

        if [ -f "$2/$profile_id/profile_folders" ]; then
            while read -r folder; do
                folder_short="$(echo "$folder" | cut -d "|" -f 2)"
                printf "%-*s|%-*s|%-*s|%-*s|\n" "$max_id_length" "$row_id" \
                    "$max_profile_id_length" "$profile_id" "$max_profile_name_length" \
                    "$profile_name" "$max_folder_length" "$folder_short"
                row_id="$((row_id + 1))"
                if [ -f "$2/$profile_id/$folder_id/formated_mails" ]; then
                    while read -r mail; do
                        echo "$mail" | sed "s/R$row_id_place_padding/$(printf "%*s" "$max_id_length" "$row_id")/"
                        row_id="$((row_id + 1))"
                    done < "$2/$profile_id/$folder_id/formated_mails"
                fi
                folder_id="$((folder_id + 1))"
            done < "$2/$profile_id/profile_folders"
        fi
    done < "$1"
}

render_tree() {
    #$1 = path to config
    # Optional: render folder content
    #$2 = profile_id
    #$3 = folder name
    pre_tree="$(xargs -I "__" sh -c \
        'mail_path="$(echo "__" | awk -F "|" '\''{print $4}'\'')";
        profile_id="$(echo "__" | awk -F "|" '\''{print $1}'\'')";
        profile_name="$(echo "__" | awk -F "|" '\''{print $2}'\'')";
        mail_folders="$(mdirs -a "$mail_path")";
        mail_count_folder="$(echo "$mail_folders" |
            xargs -I "{}" sh -c "mlist \"{}\" | wc -l" | tr "\n" ",")";

        echo "$mail_folders" | \
        awk -v id="$profile_id" -v name="$profile_name" -v parent_folder="$mail_path" -v mail_count="$mail_count_folder" \
            '\''BEGIN {
                    i = 1;
                    printf "%s\n%-6s|%-3s|%s\n%s\n", "-header-dummy-","ROW_PL", id, name, "-header-dummy-"
                } {
                    folder=substr(gensub(parent_folder "/", "", "g"),0,22);
                    split(mail_count, m_count, ",");
                    printf "%-6s|%-3s|%-25s|%-22s|%s\n", "ROW_PL", id, name, folder, m_count[i++]
                }
                END {printf "%-6s|%-3s|%-25s|%s\n%-6s|%-3s|%-25s|%s\n", "ROW_PL", id, name, "<New Mail>", "ROW_PL", id, name, "<Attachment(s)>"}'\'' ' < "$1")"

    if [ "$2" != "" ]; then
        profile_name="$(get_name_by_profile "$1" "$2")"
        folder_content="$(render_folder_content "$1" "$2" "$3")"
        folder_id="$(echo "$pre_tree" | grep -vE '^-header-dummy-' | \
            grep -En "$2.*\|.*\|$(echo "$3" | sed 's/[.[\*^$()+?{|]/\\&/g')" | \
            head -n 1 | awk -F ":" '{print $1}')"
    fi

    max_line_length="$(echo "$pre_tree" | wc -L)"
    header="$(printf "%*s" "$max_line_length" " " | tr " " "-")"
    pre_tree="$(echo "$pre_tree" |  awk -v profile_id="$2" -v profile_name="$profile_name" \
        -v folder_id="$folder_id" \
        'BEGIN { i = 1 }
         {if (match($0,/ROW_PL/)) {
             id=sprintf("%-6s", i++);
             if (folder_id == "") {
                 gsub("ROW_PL", id);
                 gsub("PPL", sprintf("%-3s", profile_id));
                 gsub("PROFILE_NAME_PL", sprintf("%-25s", profile_name));
                 gsub("FOIDPL", sprintf("%-6s", folder_id));
             } print;
         } else print $0;
         if ((i-1) == folder_id) print "folder-content-dummy"; }')"

    if [ "$2" != "" ]; then
        header="$(printf "%*s" "$max_line_length" " " | tr " " "-")"
        pre_tree="$(echo "$pre_tree" | awk -v folder_content="$folder_content" \
            'BEGIN {i = 0}
             {gsub("folder-content-dummy", folder_content); print}' | \
            awk -v profile_id="$2" -v profile_name="$profile_name" -v folder_id="$folder_id" \
        'BEGIN { i = 1 }
        {if (match($0,/ROW_PL/)) {
            id=sprintf("%-6s", i++);
            gsub("ROW_PL", id);
            gsub("PPL", sprintf("%-3s", profile_id));
            gsub("PROFILE_NAME_PL", sprintf("%-25s", profile_name));
            gsub("FOIDPL", sprintf("%-6s", folder_id)); print
        } else print $0; }')"
    fi

    echo "$pre_tree" | sed "s/-header-dummy-/$header/"
}
