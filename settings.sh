#!/bin/sh

profiles="$HOME/mail-profiles"

recipients_path=""

editor="nvim"

flag_delimiter=","

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

fzf_header="row   |id |profile                  |folder;flags|date     |mails;subject       |from"
