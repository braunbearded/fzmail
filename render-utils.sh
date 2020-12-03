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
        flags="$(echo "__" | grep -oE "2,.*" | cut -c 3-)";
        [ "$(echo "$flags" | grep -o "S")" = "" ] && flags="${flags}U";
        printf "%s|%s|%s|%s\n" "$flags" "$date" "$subject" "$from"' | \
            awk -F "|" 'BEGIN {i = 1} {printf "%-6s|%-3s|%s|%s|%-6s|%-8s|%s|%-20s|%-20s\n",
                    "ROW_PL", "PPL", "PROFILE_NAME_PL", "FOIDPL", i++, $1, $2, $3, $4}'
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
                END {printf "%-6s|%-3s|%-25s|%s\n", "ROW_PL", id, name, "<New Mail>"}'\'' ' < "$1")"

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
