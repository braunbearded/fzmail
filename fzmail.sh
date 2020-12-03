#!/bin/sh

. ./settings.sh

. ./profile-utils.sh
. ./maildir-utils.sh
. ./fzf-utils.sh
. ./render-utils.sh

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
        from="$(get_sender_by_profile "$profiles" "$selected_profile_id")"
        to="$(fzf_add_list "$(get_recipients "$profiles")" "To: ")"
        cc="$(fzf_add_list "$(get_recipients "$profiles")" "Cc: ")"
        bcc="$(fzf_add_list "$(get_recipients "$profiles")" "Bcc: ")"
        # draft="$(generate_mail "new" "$(get_profile "draft" "$selected_sender")" -f "$from" -t "$to" -c "$cc" -b "$bcc" -l "D")"
        # eval "$open_mail $draft" # TODO
        # send_mail "$draft" "$(get_profile "ident" "$selected_sender")" # TODO
    fi

    # mail selected
    if [ "${#selected_type}" = 6 ]; then
        flags="$(echo "$selected_entry" | awk -F "|" '{print $6}')"
        selected_mail_operation="$(filter_operations "$mail_operations" "$flags" "=" | \
            fzf --prompt "What to do with selected mail(s)? ")"
        [ "$selected_mail_operation" = "" ] || [ "$selected_mail_operation" = "exit" ] && continue

        folder_id="$(echo "$selected_entry" | awk -F "|" '{print $4}')"
        mail_id="$(echo "$selected_entry" | awk -F "|" '{print $5}')"
        folder="$(echo "$tree" | grep -E "^$folder_id" | awk -F "|" '{print $4}' | xargs)"
        mail_path="$(get_mails_by_profile "$profiles" "$selected_profile_id" "$folder" | sed "$mail_id!d")"

        [ "$selected_mail_operation" = "read in editor" ] && mshow -N -n "$mail_path" | "$editor" -c "set buftype=nofile" -c "setfiletype mail" -

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

        [ "$selected_mail_operation" = "reply" ] && echo "TODO"

        [ "$selected_mail_operation" = "forward" ] && echo "TODO"

        [ "$selected_mail_operation" = "download attachment(s)" ] && echo "TODO"

        [ "$selected_mail_operation" = "edit" ] && echo "TODO"
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
