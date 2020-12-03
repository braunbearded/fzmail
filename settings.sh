#!/bin/sh

profiles="$HOME/mail-profiles"

recipients_path=""

editor="nvim"

flag_delimiter=","

mail_operations="read in editor
read in browser
mark as read=1
mark as unread=2
reply=34
move to trash=4
move to folder=3
download attachment(s)
forward=3
delete=4
edit
exit"

fzf_header="row   |id |profile                  |folder;flags|date     |mails;subject       |from"

fzf_pre_folder_header="--------------------------------------------------------"
