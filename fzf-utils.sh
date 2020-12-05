#!/bin/sh

. ./profile-utils.sh
. ./render-utils.sh
. ./general-utils.sh

nl="
"

filter_operations() {
    #$1 = input to choose from
    #$2 = filter flags
    #$3 = delimiter
    flags_regex="$(echo "$2" | awk '{print $1}' | grep -o . | \
        awk '{output = $1 "|" output} END {print "(" substr(output, 1, length(output)-1) ")"}')"
    echo "$1" | grep -vE "$flags_regex" | cut -d "$3" -f 1
}

fzf_add_list() {
    #$1 = input to choose from
    #$2 = prompt
    #$3 = preselected values, if any
    data="$(printf "%s\nexit" "$1" | remove_empty_lines)"
    if [ "$3" != "" ]; then
        list="$3, "
        multiline_list="$(echo "$list" | sed "s/,/\n/g" | awk '{$1=$1;print}')$nl$data"
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

fzf_preview_folder() {
    #$1 = profile path
    #$2 = current entry
    #$3 = tree
    element_type="$(echo "$2" | awk -F "|" '{print $4}')"
    profile_id="$(echo "$2" | awk -F "|" '{print $2}')"

    # mail
    if [ "${#element_type}" = 6 ]; then
        # mail_id="$(echo "$2" | awk -F "|" '{print $5}')"
        # folder="$(echo "$3" | grep -E "^$folder_id" | awk -F "|" '{print $4}' | xargs)"
        # mail_path="$(get_mails_by_profile "$1" "$profile_id" "$folder" | sed "$mail_id!d")"
        # mshow -N -n "$mail_path"
        echo "Mail dummy"
    fi

    # folder
    if [ "${#element_type}" = 22 ]; then
        folder="$(echo "$element_type" | xargs)"
        get_mails_by_profile "$1" "$profile_id" "$folder" | \
            # version 1
            #xargs -I "{}" sh -c "mshow -N -n '{}' | head -n 10 && echo "$fzf_pre_folder_header" "

            # version 2
            xargs -I "{}" sh -c ". ./render-utils.sh && render_folder_content_short '{}'"
    fi
}
