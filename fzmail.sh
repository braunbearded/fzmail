#!/bin/sh

. ./settings.sh

. ./profile-utils.sh
. ./maildir-utils.sh
. ./fzf-utils.sh

render=true
while true; do
    if [ "$render" = true ]; then
        tree="$(./render-tree.sh "$selected_entry" "$mails_folder")"
        render=false
    fi

    selected_entry="$(echo "$tree" | fzf --tac --header "$fzf_header" | tr -d "\n")"
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
        selected_mail_operation="$(filter_operations "$mail_operations" "$flags" "=" | fzf --prompt "What to do with selected mail(s)? ")"
        [ "$selected_mail_operation" = "" ] || [ "$selected_mail_operation" = "exit" ] && continue

        folder_id="$(echo "$selected_entry" | awk -F "|" '{print $4}')"
        mail_id="$(echo "$selected_entry" | awk -F "|" '{print $5}')"
        folder="$(echo "$tree" | grep -E "^$folder_id" | awk -F "|" '{print $4}' | xargs)"
        mail_path="$(get_mails_by_profile "$profiles" "$selected_profile_id" "$folder" | sed "$mail_id!d")"

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

    # folder selected
    if [ "${#selected_type}" = 22 ]; then
        folder="$(echo "$selected_entry" | awk -F "|" '{print $4}' | xargs)"
        mails_folder="$(get_mails_by_profile "$profiles" "$selected_profile_id" "$folder")"
    fi
done
