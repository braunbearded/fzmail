#!/bin/sh

mail_profiles="$HOME/.config/mail-profiles"

operations="list
new mail
refresh sequenz
exit"

mail_operations="read in editor
read in browser
mark as read=1
mark as unread=2
reply=3
move to trash=3
move to folder
download attachment(s)
forward
delete=3
edit=3
exit"

#TODO
# download attachment, edit

mflagmv() {
    mail_source="$(mflag "$2" "$1")"
    mail_dest="$(echo "$mail_source" | sed "s/$3.*//")"
    [ "$mail_source" = "$mail_dest" ] && return
    mrefile "$mail_source" "$mail_dest"
}

get_mail_flags() {
    flag="$(echo "$@" | cut -c 2-2)"
    case "$flag" in
        ".") echo "2";;
        " ") echo "1";;
        "x") echo "3";;
    esac
}

filtered_operations() {
    flag="$(get_mail_flags "$selected_mail")"
    echo "$mail_operations" | grep -v "$flag" | cut -d '=' -f 1
}

while true; do
    selected_mail=""
    selected_mail_operation=""
    selected_id=""

    selected_operation="$(echo "$operations" | fzf --prompt "Select operation type: ")"
    [ "$selected_operation" = "" ] && exit

    if [ "$selected_operation" = "list" ]; then
        selected_mail="$(mscan -f '%c%u%r %-3n %16D %17f %t %15F %t %2i%s' | fzf --prompt "Select mail(s) to work on: " \
            --preview 'mshow -N -n -A "text/plain" "$(echo {} | grep -oE "^....[0-9]*" | cut -c 5-)"')"
        [ "$selected_mail" = "" ] && continue

        selected_mail_operation="$(filtered_operations | fzf --prompt "What to do with selected mail(s)? ")"
        [ "$selected_mail_operation" = "" ] || [ "$selected_mail_operation" = "exit" ] && continue

        selected_id="$(echo "$selected_mail" | grep -oE "^....[0-9]*" | cut -c 5-)"
        if [ "$selected_mail_operation" = "mark as read" ]; then
            # TODO check if valid id
            mflagmv "$selected_id" "-S" "\/new\/"
        fi

        if [ "$selected_mail_operation" = "mark as unread" ]; then
            # TODO check if valid id
            mflagmv "$selected_id" "-s" "\/cur\/"
        fi

        if [ "$selected_mail_operation" = "read in editor" ]; then
            mshow -N -n "$selected_id" | nvim -c "set buftype=nofile" -c "setfiletype mail" -
        fi

        if [ "$selected_mail_operation" = "read in browser" ]; then
            mshow -h "" -N -n -A "text/html" "$selected_id" | firefox "data:text/html;base64,$(base64 -w 0 <&0)"
            # TODO switch to window
        fi

        if [ "$selected_mail_operation" = "delete" ]; then
            rm "$(mseq "$selected_id")"
        fi

        if [ "$selected_mail_operation" = "move to folder" ]; then
            selected_folder="$(echo "$selected_mail" | cut -c 46-63)"
            target_folders="$(mdirs "$MAILDIR" | grep -v "$selected_folder" | fzf --prompt "Move folder to: ")"
            [ "$target_folders" = "" ] && continue
            mail_source="$(mseq "$selected_id")"
            [ "$(echo "$target_folders" | grep -o "Trash")" = "Trash" ] && mail_source="$(mflag "-T" "$selected_id")"
            mrefile "$mail_source" "$target_folders"
        fi

        if [ "$selected_mail_operation" = "move to trash" ]; then
            selected_folder="$(echo "$selected_mail" | cut -c 46-63)"
            target_folders="$(dirname "$(dirname "$(dirname "$(mseq 1)")")")/Trash"
            [ "$(echo "$selected_folder" | grep -o "Trash")" = "Trash" ] && continue
            mail_source="$(mflag "-T" "$selected_id")"
            mrefile "$mail_source" "$target_folders"
        fi

        if [ "$selected_operation" = "reply" ]; then
            from="$(cat "$(mseq "$selected_id")" | grep -i "from:" | grep -oE "\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b")"
            from_long="$(cat "$(mseq "$selected_id")" | grep -i "from:" | cut -c 7-)"
            to="$(cut -d "|" -f 1 "$mail_profiles" | fzf --prompt "To: ")"
            to_old="$(cat "$(mseq "$selected_id")" | grep -i "to:" | cut -c 5-)"
            cc="$(cut -d "|" -f 1 "$mail_profiles" | fzf --prompt "Cc (ESC for none): ")"
            cc_old="$(cat "$(mseq "$selected_id")" | grep -i "cc:" | cut -c 5-)"
            bcc="$(cut -d "|" -f 1 "$mail_profiles" | fzf --prompt "Bcc (ESC for none): ")"
            bcc_old="$(cat "$(mseq "$selected_id")" | grep -i "bcc:" | cut -c 6-)"
            new_message_id="$(mgenmid)"
            old_message_id="$(cat "$(mseq "$selected_id")" | grep -i "message-id:" | cut -c 13-)"
            new_subject="Re: $(cat "$(mseq "$selected_id")" | grep -i "subject:" | cut -c 10-)"
            draft_maildir="$(grep "$from" "$mail_profiles" | cut -d "|" -f 3)"
            quote_start="$from_long wrote:"
            content="$(mshow -O "$selected_id" 2 | sed -e 's/^/> /')"

            draft_file="$(printf "To: %s\nCc: %s\nBcc: %s\nSubject: %s\nFrom: %s\nReferences: %s\nIn-Reply-To: %s\nMessage-Id: %s\n\n%s\n%s" "$from" "$cc" "$bcc" "$new_subject" "$to_old" "$old_message_id" "$old_message_id" "$new_message_id" "$quote_start" "$content" | mdeliver -v -c -XD "$draft_maildir")"
            nvim -c "setfiletype mail" "$draft_file"
            send_draft="$(printf "Yes\nNo" | fzf --prompt "Send draft?")"
            if [ "$send_draft" = "Yes" ]; then
                # sent_maildir="$(grep "$from" "$mail_profiles" | cut -d "|" -f 4)"
                mail_source="$(mflag "-d" "$draft_file")"
                # mrefile "$mail_source" "$sent_maildir"
            fi
        fi

        if [ "$selected_operation" = "forward" ]; then
            from="$(cat "$(mseq "$selected_id")" | grep -i "from:" | grep -oE "\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b")"
            from_long="$(cat "$(mseq "$selected_id")" | grep -i "from:" | cut -c 7-)"
            draft_maildir="$(grep "$from" "$mail_profiles" | cut -d "|" -f 3)"
            cc_old="$(cat "$(mseq "$selected_id")" | grep -i "cc:" | cut -c 5-)"
            bcc_old="$(cat "$(mseq "$selected_id")" | grep -i "bcc:" | cut -c 6-)"
            to="$(cut -d "|" -f 1 "$mail_profiles" | fzf --prompt "To: ")"
            new_subject="Fwd: $(cat "$(mseq "$selected_id")" | grep -i "subject:" | cut -c 10-)"
            content="message/rfc822#inline /path/to/inbox/cur/1606464263.7133_1.slapacer,U=1:2,S>"

            draft_file="$(printf "To: %s\nCc: %s\nBcc: %s\nSubject: %s\nFrom: %s\nReferences: %s\nIn-Reply-To: %s\nMessage-Id: %s\n\n%s\n%s" "$from" "$cc" "$bcc" "$new_subject" "$to_old" "$old_message_id" "$old_message_id" "$new_message_id" "$quote_start" "$content" | mdeliver -v -c -XD "$draft_maildir")"
            nvim -c "setfiletype mail" "$draft_file"
            send_draft="$(printf "Yes\nNo" | fzf --prompt "Send draft?")"
            if [ "$send_draft" = "Yes" ]; then
                mail_source="$(mflag "-d" "$draft_file")"
            fi
        fi
    fi

    if [ "$selected_operation" = "refresh sequenz" ]; then
        mdirs "$MAILDIR" | mlist | mseq -S
    fi

    if [ "$selected_operation" = "exit" ]; then
        exit
    fi

    if [ "$selected_operation" = "new mail" ]; then
        from="$(cut -d "|" -f 1 "$mail_profiles" | fzf -d "|" -n 1 --prompt "From: ")"
        to="$(cut -d "|" -f 1 "$mail_profiles" | fzf --prompt "To: ")"
        cc="$(cut -d "|" -f 1 "$mail_profiles" | fzf --prompt "Cc (ESC for none): ")"
        bcc="$(cut -d "|" -f 1 "$mail_profiles" | fzf --prompt "Bcc (ESC for none): ")"
        message_id="$(mgenmid)"
        draft_maildir="$(grep "$from" "$mail_profiles" | cut -d "|" -f 3)"
        draft_file="$(printf "To: %s\nCc: %s\nBcc: %s\nSubject: \nFrom: %s\nMessage-Id: %s\n\n" "$to" "$cc" "$bcc" "$from" "$message_id" | mdeliver -v -c -XD "$draft_maildir")"
        nvim -c "setfiletype mail" "$draft_file"
        send_draft="$(printf "Yes\nNo" | fzf --prompt "Send draft?")"
        if [ "$send_draft" = "Yes" ]; then
            # sent_maildir="$(grep "$from" "$mail_profiles" | cut -d "|" -f 4)"
            mail_source="$(mflag "-d" "$draft_file")"
            # mrefile "$mail_source" "$sent_maildir"
        fi
    fi
done



