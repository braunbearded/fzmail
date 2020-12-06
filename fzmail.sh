#!/bin/sh

. ./settings.sh

. ./profile-utils.sh
. ./maildir-utils.sh
. ./fzf-utils.sh
. ./render-utils.sh
. ./general-utils.sh

render=true
current_folder=''
while true; do
    if [ "$render" = true ]; then
        tree="$(render_tree "$profiles" "$selected_profile_id" "$folder")"
        render=false
    fi

    selected_entry="$(echo "$tree" | fzf --tac --header "$fzf_header" \
        --preview ". ./fzf-utils.sh && fzf_preview_folder $profiles {}" \
        --preview-window "right:33%" | tr -d "\n")"
    [ "$selected_entry" = "" ] && exit

    selected_type="$(echo "$selected_entry" | awk -F "|" '{print $4}')"
    selected_profile_id="$(echo "$selected_entry" | awk -F "|" '{print $2}')"
    profile_path="$(get_path_by_profile "$profiles" "$selected_profile_id")"

    # new mail selected
    if [ "$selected_type" = "<New Mail>" ]; then
        render=true
        from="$(get_sender_by_profile "$profiles" "$selected_profile_id")"
        to="$(fzf_add_list "$(get_recipients "$profiles" "$mail_addresses_path")" "To: ")"
        cc="$(fzf_add_list "$(get_recipients "$profiles" "$mail_addresses_path")" "Cc: ")"
        bcc="$(fzf_add_list "$(get_recipients "$profiles" "$mail_addresses_path")" "Bcc: ")"
        draft_path="$profile_path/$(get_draft_by_profile "$profiles" "$selected_profile_id")"
        draft="$(./generate-mail.sh "new" "$draft_path" -f "$from" -t "$to" -c "$cc" -b "$bcc" -l "D")"
        "$edit_mail" -c "setfiletype mail" "$draft"
        confirm_send="$(printf "Yes\nNo" | fzf --prompt "Send this draft? ")"
        if [ "$confirm_send" = "Yes" ]; then
            tmp_file="$draft$(date +%s)"
            cp "$draft" "$tmp_file" && ./convert-mail.sh "new" "$tmp_file" > "$draft" \
                && rm "$tmp_file" && msmtp --read-envelope-from -t < "$draft" && rm "$draft"
        fi
        confirm_sync="$(printf "Yes\nNo" | fzf --prompt "Sync imap? ")"
        [ "$confirm_sync" = "Yes" ] && mbsync -c "$mbsync_config" -a
    fi

    if [ "$selected_type" = "<Attachment(s)>" ]; then
        attachment_folder="$(get_attachment_by_profile "$profiles" "$selected_profile_id")"
        selected_file="$(find "$attachment_folder" -type f | fzf --prompt "Select attachment: ")"
        [ "$selected_file" = "" ] && continue
        operation="$(echo "$attachment_operations" | fzf --prompt "Select operation for \"$selected_file\": ")"
        [ "$operation" = "remove" ] && rm "$selected_file"
        [ "$operation" = "open" ] && xdg-open "$selected_file"
    fi

    # mail selected
    if [ "${#selected_type}" = 6 ]; then
        flags="$(echo "$selected_entry" | awk -F "|" '{print $6}')"
        [ "$(echo "$flags" | grep -o "D")" = "" ] && flags="Z${flags}"
        [ "$(echo "$flags" | grep -o "A")" = "" ] && flags="Y${flags}"
        converted_flags="$(convert_flags "$flags")"
        selected_mail_operation="$(filter_operations "$mail_operations" "$converted_flags" "=" | \
            fzf --prompt "What to do with selected mail(s)? ")"
        [ "$selected_mail_operation" = "" ] || [ "$selected_mail_operation" = "exit" ] && continue

        folder_id="$(echo "$selected_entry" | awk -F "|" '{print $4}')"
        mail_id="$(echo "$selected_entry" | awk -F "|" '{print $5}')"
        folder="$(echo "$tree" | grep -E "^$folder_id" | awk -F "|" '{print $4}' | xargs)"
        mail_path="$(get_mails_by_profile "$profiles" "$selected_profile_id" "$folder" | sed "$mail_id!d")"

        [ "$selected_mail_operation" = "read in editor" ] && mshow -N -n "$mail_path" | "$edit_mail" -c "set buftype=nofile" -c "setfiletype mail" -

        [ "$selected_mail_operation" = "read in browser" ] && mshow -h "" -N -n -A "text/html" "$mail_path" | firefox "data:text/html;base64,$(base64 -w 0 <&0)"

        [ "$selected_mail_operation" = "delete" ] && rm "$mail_path" && render=true

        [ "$selected_mail_operation" = "mark as read" ] && render=true && set_flag_mail "$(move_mail_to_cur "$mail_path")" "S" > /dev/null

        [ "$selected_mail_operation" = "mark as unread" ] && render=true && remove_flag_mail "$(move_mail_to_cur "$mail_path")" "S" > /dev/null

        if [ "$selected_mail_operation" = "move to folder" ]; then
            target_folder="$(get_mail_folders "$profile_path" | \
                awk -v profile_path="$profile_path" '{gsub(profile_path "/",""); print}' | \
                fzf --prompt "Select folder to move mail to: ")"
            [ "$target_folder" = "" ] && continue
            render=true
            move_mail_to_folder "$mail_path" "$target_folder" "$profile_path" > /dev/null
        fi

        if [ "$selected_mail_operation" = "move to trash" ]; then
            render=true
            trash_path="$(get_trash_by_profile "$profiles" "$selected_profile_id")"
            new_path="$(move_mail_to_folder "$mail_path" "$trash_path" "$profile_path")"
            set_flag_mail "$new_path" "T" > /dev/null
        fi

        if [ "$selected_mail_operation" = "reply" ]; then
            orig_from="$(echo "$mail_path" | mshow -q -h from | cut -c 7-)"
            orig_to="$(echo "$mail_path" | mshow -q -h to | cut -c 5-)"
            orig_cc="$(echo "$mail_path" | mshow -q -h cc | cut -c 5-)"
            orig_bcc="$(echo "$mail_path" | mshow -q -h bcc | cut -c 6-)"
            orig_from_header="$(echo "Old-From: $orig_from")"

            from="$(get_sender_by_profile "$profiles" "$selected_profile_id")"
            to="$(fzf_add_list "$(get_recipients "$profiles" "$mail_addresses_path")" "Reply to: " "$orig_from")"
            cc="$(fzf_add_list "$(get_recipients "$profiles" "$mail_addresses_path")" "Reply cc: " "$orig_cc")"
            bcc="$(fzf_add_list "$(get_recipients "$profiles" "$mail_addresses_path")" "Reply bcc: " "$orig_bcc")"
            draft_path="$profile_path/$(get_draft_by_profile "$profiles" "$selected_profile_id")"
            draft="$(./generate-mail.sh "reply" "$draft_path" "$mail_path" -f "$from" -t "$to" -c "$cc" -b "$bcc" -l "D" -h "$orig_from_header")"
            "$edit_mail" -c "setfiletype mail" "$draft"
            confirm_send="$(printf "Yes\nNo" | fzf --prompt "Send this draft? ")"
            if [ "$confirm_send" = "Yes" ]; then
                tmp_file="$draft$(date +%s)"
                cp "$draft" "$tmp_file" && ./convert-mail.sh "reply" "$tmp_file" > "$draft" \
                    && rm "$tmp_file" && msmtp --read-envelope-from -t < "$draft" && rm "$draft"
            fi
            confirm_sync="$(printf "Yes\nNo" | fzf --prompt "Sync imap? ")"
            [ "$confirm_sync" = "Yes" ] && mbsync -c "$mbsync_config" -a
        fi

        if [ "$selected_mail_operation" = "forward" ]; then
            from="$(get_sender_by_profile "$profiles" "$selected_profile_id")"
            to="$(fzf_add_list "$(get_recipients "$profiles" "$mail_addresses_path")" "Forward to: ")"
            cc="$(fzf_add_list "$(get_recipients "$profiles" "$mail_addresses_path")" "Forward cc: ")"
            bcc="$(fzf_add_list "$(get_recipients "$profiles" "$mail_addresses_path")" "Forward bcc: ")"
            draft_path="$profile_path/$(get_draft_by_profile "$profiles" "$selected_profile_id")"
            draft="$(./generate-mail.sh "forward" "$draft_path" "$mail_path" -f "$from" -t "$to" -c "$cc" -b "$bcc" -l "D")"
            "$edit_mail" -c "setfiletype mail" "$draft"
            # TODO
            confirm_send="$(printf "Yes\nNo" | fzf --prompt "Send this draft? ")"
            [ "$confirm_send" = "Yes" ] && msmtp --read-envelope-from -t < "$draft" && rm "$draft"
            confirm_sync="$(printf "Yes\nNo" | fzf --prompt "Sync imap? ")"
            [ "$confirm_sync" = "Yes" ] && mbsync -c "$mbsync_config" -a
        fi

        if [ "$selected_mail_operation" = "download attachment(s)" ]; then
            file_names="$(grep -oE "Content-Disposition: attachment; filename=\".*\"" < "$mail_path" | cut -d "\"" -f 2)"
            attachment_folder="$(get_attachment_by_profile "$profiles" "$selected_profile_id")"
            [ ! -d "$attachment_folder" ] && mkdir -p "$attachment_folder"
            i=1
            for file_name in $file_names; do
                full_file_name="$attachment_folder/$file_name"
                [ -f "$full_file_name" ] && full_file_name="$full_file_name$(date +%s)"
                tr -d "\n" < "$mail_path" | grep -oE "[a-zA-Z0-9\+/]*=[-=]" | \
                    tr -d "-" | sed -n "${i}p" | base64 -d > "$full_file_name"
                i="$((i+1))"
            done
        fi

        #TODO
        if [ "$selected_mail_operation" = "edit" ]; then
            "$edit_mail" -c "setfiletype mail" "$mail_path"
            if [ "$(echo "$flags" | grep -o "D")" != "" ]; then
                confirm_send="$(printf "Yes\nNo" | fzf --prompt "Send this draft? ")"
                [ "$confirm_send" = "Yes" ] && msmtp --read-envelope-from -t < "$draft" && rm "$draft"
                confirm_sync="$(printf "Yes\nNo" | fzf --prompt "Sync imap? ")"
                [ "$confirm_sync" = "Yes" ] && mbsync -c "$mbsync_config" -a
                render=true
            fi
        fi
    fi

    # folder selecte
    if [ "${#selected_type}" = 22 ]; then
        if [ "$selected_entry" = "$current_folder" ]; then
            current_folder=''
            unset folder
        else
            current_folder=$selected_entry
            folder="$(echo "$selected_entry" | awk -F "|" '{print $4}' | xargs)"
            mails_folder="$(get_mails_by_profile "$profiles" "$selected_profile_id" "$folder")"
        fi
        render=true
    fi
done
