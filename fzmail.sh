#!/bin/sh

profiles_path="$HOME/mail-profiles"
recipients_path=""
editor="nvim"

flag_delimiter=","

fzf_header="row   |id |profile                  |folder;flags|date     |mails;subject       |from"

mail_operations="read in editor
read in browser
mark as read=S
mark as unread=U
reply=T
move to trash=T
move to folder
download attachment(s)
forward
delete=T
edit=T
exit"

nl="
"

render_mail_tree() {
    tmpcontent=$(mktemp -u)
    tmpcounter1=$(mktemp -u)
    echo 0 > "$tmpcounter1"
    rep_entry="$1"
    rep_content="$2"
    while read -r profile; do
        id="$(echo "$profile" | awk -F "|" '{print $1}')"
        mail="$(echo "$profile" | awk -F "|" '{print $2}')"
        mail_path="$(echo "$profile" | awk -F "|" '{print $4}')"
        mail_path_length="${#mail_path}"
        echo "$(( $(cat "$tmpcounter1")+1))" > "$tmpcounter1"
        row_number="$(cat "$tmpcounter1")"
        header="$(printf "%-6s|%-3s|%-25s\n" "$row_number" "$id" "$mail")"
        header_placeholder="header_placeholder"
        printf "%s\n%s\n%s\n" "$header_placeholder" "$header" "$header_placeholder" >> "$tmpcontent"
        mdirs "$mail_path" | while read -r folder; do
            folder_short="$(echo "$folder" | cut -c "$((mail_path_length + 2))-")"
            mails="$(mlist "$mail_path/$folder_short")"
            mail_count="$(echo "$mails" | wc -l)"
            folder_format="$(echo "$folder_short" | cut -c 1-20)"
            echo "$(( $(cat "$tmpcounter1")+1))" > "$tmpcounter1"
            row_number="$(cat "$tmpcounter1")"
            formatted_row="$(printf "%-6s|%-3s|%-25s|%-22s|%s" "$row_number" "$id" "$mail" "$folder_format" "($mail_count)")"
            printf "%s\n" "$formatted_row" >> "$tmpcontent"
            if [ "$rep_entry" = "$formatted_row" ]; then
                folder_id="$row_number"
                tmpcounter2=$(mktemp -u)
                echo 0 > "$tmpcounter2"
                echo "$rep_content" | while read -r mail_folder_entry; do
                    subject="$(mshow -n -q -h subject "$mail_folder_entry" | cut -c 10-29)"
                    date="$(date -d "$(mshow -n -q -h date "$mail_folder_entry" | grep -oE "[0-9]+ [A-Z][a-z][a-z] [0-9][0-9][0-9][0-9] [0-9][0-9]:[0-9][0-9]")" +"%Y-%m-%d %H:%M")"
                    from="$(mshow -n -q -h from "$mail_folder_entry" | cut -c 7-)"
                    echo "$(( $(cat "$tmpcounter1")+1))" > "$tmpcounter1"
                    row_number="$(cat "$tmpcounter1")"
                    echo "$(( $(cat "$tmpcounter2")+1))" > "$tmpcounter2"
                    mail_counter="$(cat "$tmpcounter2")"
                    flags="$(echo "$mail_folder_entry" | grep -oE "2$flag_delimiter.*" | cut -c 3-)"
                    if [ "$(echo "$flags" | grep -o "S")" = "" ]; then
                        flags="${flags}U"
                    fi
                    printf "%-6s|%-3s|%-25s|%-6s|%-6s|%-8s|%s|%-20s|%-20s\n" "$row_number" "$id" "$mail" "$folder_id" "$mail_counter" "$flags" "$date" "$subject" "$from" >> "$tmpcontent"
                done
                rm "$tmpcounter2"
            fi
        done
        echo "$(( $(cat "$tmpcounter1")+1))" > "$tmpcounter1"
        row_number="$(cat "$tmpcounter1")"
        printf "%-6s|%-3s|%-25s|%s\n" "$row_number" "$id" "$mail" "<New Mail>" >> "$tmpcontent"
    done < "$profiles_path"

    rm "$tmpcounter1"
    pre_content="$(cat "$tmpcontent")"
    rm "$tmpcontent"
    max_line_length="$(echo "$pre_content" | wc -L)"
    header_delimiter="$(printf "%*s" "$max_line_length" " " | tr " " "-")"
    echo "$pre_content" | sed "s/$header_placeholder/$header_delimiter/"
}

get_mails() {
    #$1 = profile id
    #$2 = folder
    profile="$(sed "$1!d" "$profiles_path")"
    mail_path="$(echo "$profile" | awk -F "|" '{print $4}')/$2"
    mlist "$mail_path"
}

filter_operations() {
    flags_regex="$(echo "$1" | awk '{print $1}' | grep -o . | awk '{output = $1 "|" output} END {print "(" substr(output, 1, length(output)-1) ")"}')"
    echo "$mail_operations" | grep -v "$flags_regex" | cut -d '=' -f 1
}

get_sender() {
    sed "$1!d" "$profiles_path" | awk -F "|" '{print $3}'
}

get_recipients() {
    awk -F "|" '{print $4}' "$profiles_path" | xargs -I "{}" sh -c "find {} -type f ! -name '.*'" | maddr | sort -u
}

fzf_add_list() {
    #$1 = input to choose from
    #$2 = prompt
    #$3 = preselected values
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

generate_mail() {
    if [ "$1" = "new" ] && [ -d "$2" ]; then
        draft_path="$2"
        shift
        shift
        while [ "$1" != "" ]; do
            case $1 in
                -f) from="$2"; shift;;
                -t) to="$2"; shift;;
                -c) cc="$2"; shift;;
                -b) bcc="$2"; shift;;
                -l) flag="$2"; shift;;
                -s) subject="$2"; shift;;
                -h) other_header="$2"; shift;;
                -o) content="$2"; shift;;
            esac
            shift
        done
        message_id="$(mgenmid)"
        printf "To: %s\nCc: %s\nBcc: %s\nFrom: %s\nMessage-Id: %s\nSubject: %s\n%s\n\n%s" "$to" "$cc" "$bcc" "$from" "$message_id" "$subject" "$other_header" "$content" | mdeliver -v -c -XD "$draft_path"
    fi
}

render=true
while true; do
    if [ "$render" = true ]; then
        tree="$(render_mail_tree "$selected_entry" "$mails_folder")"
    fi

    selected_entry="$(echo "$tree" | fzf --tac --header "$fzf_header" | tr -d "\n")"
    [ "$selected_entry" = "" ] && exit

    selected_type="$(echo "$selected_entry" | awk -F "|" '{print $4}')"
    selected_profile_id="$(echo "$selected_entry" | awk -F "|" '{print $2}')"

    if [ "$selected_type" = "<New Mail>" ]; then
        from="$(get_sender "$selected_profile_id")"
        to="$(fzf_add_list "$(get_recipients)" "To: ")"
        cc="$(fzf_add_list "$(get_recipients)" "Cc: ")"
        bcc="$(fzf_add_list "$(get_recipients)" "Bcc: ")"
        # draft="$(generate_mail "new" "$(get_profile "draft" "$selected_sender")" -f "$from" -t "$to" -c "$cc" -b "$bcc" -l "D")"
        # eval "$open_mail $draft" # TODO
        # send_mail "$draft" "$(get_profile "ident" "$selected_sender")" # TODO
    fi

    if [ "${#selected_type}" = 6 ]; then
        render=false
        flags="$selected_type"
        selected_mail_operation="$(filter_operations "$flags" | fzf --prompt "What to do with selected mail(s)? ")"
        [ "$selected_mail_operation" = "" ] || [ "$selected_mail_operation" = "exit" ] && continue

        folder_id="$(echo "$selected_entry" | awk -F "|" '{print $4}')"
        mail_id="$(echo "$selected_entry" | awk -F "|" '{print $5}')"
        folder="$(echo "$tree" | grep -E "^$folder_id" | awk -F "|" '{print $4}' | xargs)"
        mail_path="$(get_mails "$selected_profile_id" "$folder" | sed "$mail_id!d")"

        [ "$selected_mail_operation" = "read in editor" ] && mshow -N -n "$mail_path" | "$editor" -c "set buftype=nofile" -c "setfiletype mail" -

        [ "$selected_mail_operation" = "read in browser" ] && mshow -h "" -N -n -A "text/html" "$mail_path" | firefox "data:text/html;base64,$(base64 -w 0 <&0)"

        [ "$selected_mail_operation" = "delete" ] && rm "$mail_path" && render=true

        [ "$selected_mail_operation" = "mark as read" ] && echo "TODO"

        [ "$selected_mail_operation" = "mark as unread" ] && echo "TODO"

        [ "$selected_mail_operation" = "move to folder" ] && echo "TODO"

        [ "$selected_mail_operation" = "move to trash" ] && echo "TODO"

        [ "$selected_mail_operation" = "reply" ] && echo "TODO"

        [ "$selected_mail_operation" = "forward" ] && echo "TODO"

        [ "$selected_mail_operation" = "download attachment(s)" ] && echo "TODO"

        [ "$selected_mail_operation" = "edit" ] && echo "TODO"
    fi

    if [ "${#selected_type}" = 22 ]; then
        folder="$(echo "$selected_entry" | awk -F "|" '{print $4}' | xargs)"
        mails_folder="$(get_mails "$selected_profile_id" "$folder")"
    fi
done
