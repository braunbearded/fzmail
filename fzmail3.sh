#!/bin/sh

. ./settings2.sh

[ ! -d "$cache_path" ] && ./fzcache.sh "init" "$cache_path" "$profiles"
current_mail="$cache_path/mail"
view_history="$cache_path/history"
[ ! -f "$view_history" ] && echo "main|main" > "$view_history"

while true; do
    next_view="$(tail -n 1 "$view_history")"
    view="$(echo "$next_view" | cut -d "|" -f 1)"
    view_type="$(echo "$next_view" | cut -d "|" -f 2)"
    [ ! -f "$cache_path/$view" ] && ./fzrender.sh "view" "$view" "$view_type" \
        "$cache_path" "$current_mail" > "$cache_path/$view" &
    [ ! -f "$cache_path/header_$view_type" ] && ./fzrender.sh "header" \
        "$view_type" "$cache_path" > "$cache_path/header_$view_type"

    entry="$(tail -f -n +1 "$cache_path/$view" | fzf --tac -d "\|" \
        --with-nth=6.. --preview-window "right:33%" \
        --preview "./fzrender.sh preview {} $cache_path" \
        --header "$(cat "$cache_path/header_$view_type")")"
    entry_type="$(echo "$entry" | cut -d "|" -f 1)"
    profile_id="$(echo "$entry" | cut -d "|" -f 2)"
    folder_id="$(echo "$entry" | cut -d "|" -f 3)"
    mail_id="$(echo "$entry" | cut -d "|" -f 4)"
    entry_path="$(echo "$entry" | cut -d "|" -f 5)"

    # Jump back
    if [ "$entry" = "" ]; then
        [ "$view_type" = "main" ] && exit
        if [ "$view_type" = "folder" ] || [ "$view_type" = "mail" ]; then
            last="$(tail -n 2 "$view_history" | head -n 1)"
            view="$(echo "$last" | cut -d "|" -f 1)"
            view_type="$(echo "$last" | cut -d "|" -f 2)"
            printf "%s|%s\n" "$view" "$view_type" >> "$view_history"
        elif [ "$view_type" = "operation" ] || [ "$view_type" = "attachment" ] || \
            [ "$view_type" = "folder" ]; then
            #TODO jump to far
            sed -i '$ d' "$view_history"
        fi
    fi

    # Folder selected
    if [ "$entry_type" = "folder" ]; then
        printf "%s|%s\n" "$profile_id/$folder_id/view" "folder" >> "$view_history"
    fi

    # Mail selected
    if [ "$entry_type" = "mail" ]; then
        [ -f "$cache_path/operations" ] && rm "$cache_path/operations"
        printf "%s|%s\n" "operations" "operation" >> "$view_history"
        echo "$profile_id|$folder_id|$mail_id|$entry_path" > "$current_mail"
    fi

    # General operations
    if [ "$entry_type" = "rerender" ]; then
        ./fzrender.sh "clear" "$cache_path"
        echo "main|main" > "$view_history"
    fi

    if [ "$entry_type" = "update_cache" ]; then
        [ ! -d "$cache_path" ] && ./fzcache.sh "init" "$cache_path" "$profiles"
    fi

    if [ "$entry_type" = "sync_imap" ]; then
        #TODO
        echo "sync_imap"
    fi

    [ "$entry_type" = "exit" ] && exit

    # Profile operation
    if [ "$entry_type" = "new_mail" ]; then
        draft="$(./fzutils.sh "new_draft" "$cache_path" "$profile_id")"
        "$edit_mail" "$edit_mail_options" "$draft"
        confirm_send="$(printf "Yes\nNo" | fzf --prompt "Send this draft? ")"
        [ "$confirm_send" = "Yes" ] && ./fzutils.sh "send_new" "$draft"
        ./fzcache.sh "update_folder" "$cache_path" "$profiles" "$profile_id" \
            "$folder_id"
    fi

    if [ "$entry_type" = "list_attachments" ]; then
        printf "%s|%s\n" "$profile_id/attachments" "attachment" >> "$view_history"
    fi

    # Exit operations
    if [ "$entry_type" = "exit_folder" ] || \
        [ "$entry_type" = "exit_attachment" ] || \
        [ "$entry_type" = "exit_operations" ]; then
        #TODO
        echo "exit_folder_attachment"
        exit
    fi

    # Mail operation
    if [ "$entry_type" = "read_editor" ]; then
        "$edit_mail" "$edit_mail_options" "$read_only_options" "$entry_path"
    fi

    if [ "$entry_type" = "read_browser" ]; then
        mshow -h "" -N -n -A "text/html" "$entry_path" | \
            firefox "data:text/html;base64,$(base64 -w 0 <&0)"
    fi

    if [ "$entry_type" = "mark_read" ] || [ "$entry_type" = "mark_unread" ]; then
        ./fzmaildir.sh "$entry_type" "$entry_path" > /dev/null
        ./fzcache.sh "update_folder" "$cache_path" "$profiles" "$profile_id" \
            "$folder_id"
        rm "$cache_path/operations"
        [ -f "$cache_path/$profile_id/$folder_id/view" ] && rm "$cache_path/$profile_id/$folder_id/view"
    fi

    if [ "$entry_type" = "reply" ]; then
        draft="$(./fzutils.sh "edit_draft" "$cache_path" "$profile_id" "$entry_path")"
        "$edit_mail" "$edit_mail_options" "$draft"
        confirm_send="$(printf "Yes\nNo" | fzf --prompt "Send this draft? ")"
        if [ "$confirm_send" = "Yes" ]; then
            ./fzutils.sh "send_new" "$draft"
        else
            profile_draft="$(./fzutils.sh "$profiles" "$profile_id")"
            ./fzcache.sh "update_folder" "$cache_path" "$profiles" \
                "$profile_id" "$profile_draft"
        fi
    fi

    if [ "$entry_type" = "trash" ]; then
        ./fzutils.sh "trash" "$cache_path" "$profile_id" "$entry_path"
    fi

    if [ "$entry_type" = "move" ]; then
        printf "%s|%s\n" "view" "folders" >> "$view_history"
        echo "$profile_id|$folder_id|$mail_id|$entry_path" > "$current_mail"
    fi

    if [ "$entry_type" = "move_folder" ]; then
        ./fzutils.sh "move" "$cache_path" "$profile_id" "$folder_id" "$entry_path"
    fi

    if [ "$entry_type" = "download_attachments" ]; then
        "$edit_mail" "$edit_mail_options" "$entry_path"
    fi

    if [ "$entry_type" = "forward" ]; then
        "$edit_mail" "$edit_mail_options" "$entry_path"
    fi

    if [ "$entry_type" = "delete" ]; then
        "$edit_mail" "$edit_mail_options" "$entry_path"
    fi

    if [ "$entry_type" = "edit" ]; then
        "$edit_mail" "$edit_mail_options" "$entry_path"
    fi

done

