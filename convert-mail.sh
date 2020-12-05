#!/bin/sh

. ./general-utils.sh

mime="MIME-Version: 1.0"
content_delimiter="# content below this line (dont delete this line)"
attachments="$(grep "Attachments: " "$1" | cut  -c 13- | tr ";" "\n")"
start_content="$(grep "$content_delimiter" -n "$1" | head -n 1 | cut -d ":" -f 1)"
headers="$(head -n "$((start_content - 1))" "$1" | sed '/^[[:space:]]*$/d' | grep -v "Attachments:")"

header_boundary="$(boundary_generator)"
mailtext_boundary="$(boundary_generator)"
full_header="$(printf "%s\n%s\nContent-Type: multipart/mixed; boundary=\"%s\"\n" "$mime" "$headers" "$header_boundary" )"

printf "%s\n\n" "$full_header"
printf "%s\n" "--$header_boundary"
printf "Content-Type: multipart/alternative; boundary=\"%s\"\n" "$mailtext_boundary"
printf "\n%s\n" "--$mailtext_boundary"
printf "Content-Type: text/plain; charset=\"UTF-8\"\n"
tail -n +"$((start_content + 1))" "$1"
printf "\n%s\n" "--$mailtext_boundary"
printf "Content-Type: text/html; charset=\"UTF-8\"\n"
printf "<div>\n"
tail -n +"$((start_content + 1))" "$1" | sed ':a;N;$!ba;s/\n/<br\/>\n/g'
printf "</div>\n"
printf "\n%s" "--$mailtext_boundary--"
printf "\n%s" "--$header_boundary"
for attachment in $attachments; do
    filename="$(basename "$attachment")"
    [ ! -f "$attachment" ] && continue
    printf "\nContent-Type: text/plain; charset=\"US-ASCII\"; name=\"%s\"\n" "$filename"
    printf "Content-Disposition: attachment; filename=\"%s\"\n" "$filename"
    printf "Content-Transfer-Encoding: base64\n\n"
    base64 "$attachment"
    printf "%s" "--$header_boundary"
done
printf "%s\n" "--"
