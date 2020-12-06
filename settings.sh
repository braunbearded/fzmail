#!/bin/sh

profiles="$HOME/.config/fzmail/mail-profiles"

mail_addresses_path="$HOME/.config/fzmail/mail-addresses"

edit_mail="nvim"

flag_delimiter=","

mail_operations="read in editor
read in browser
mark as read=1
mark as unread=2
reply=34
move to trash=4
move to folder=3
download attachment(s)=9
forward=3
delete=4
edit
exit"

attachment_operations="open
remove"

fzf_header="row   |id |profile                  |folder;flags|date     |mails;subject       |from"

fzf_pre_folder_header="--------------------------------------------------------"

use_mbsync=false
mbsync_config="$HOME/.config/isyncrc"
