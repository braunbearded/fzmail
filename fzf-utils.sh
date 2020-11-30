#!/bin/sh

nl="
"

filter_operations() {
    #$1 = input to choose from
    #$2 = filter flags
    #$3 = delimiter
    flags_regex="$(echo "$2" | awk '{print $1}' | grep -o . | awk '{output = $1 "|" output} END {print "(" substr(output, 1, length(output)-1) ")"}')"
    echo "$1" | grep -v "$flags_regex" | cut -d "$3" -f 1
}

fzf_add_list() {
    #$1 = input to choose from
    #$2 = prompt
    #$3 = preselected values, if any
    data="$(printf "%s\nexit" "$1")"
    if [ "$3" != "" ]; then
        list="$3, "
        multiline_list="$(echo "$list" | sed "s/,/\n/g" | awk '{$1=$1;print}')$nl$data"
        options="$(echo "$multiline_list" | sort | uniq -u)"
    else
        options="$data"
    fi

    while [ "$options" != "exit" ]; do
        selected="$(echo "$options" | fzf --prompt "$2(${list%??})")"
        [ "$selected" = "exit" ] || [ "$selected" = "" ] && { options="exit"; continue; }
        list="$selected, $list"
        multiline_list="$(echo "$list" | sed "s/,/\n/g" | awk '{$1=$1;print}')$nl$data"
        options="$(echo "$multiline_list" | sort | uniq -u)"
    done
    echo "${list%??}"
}
