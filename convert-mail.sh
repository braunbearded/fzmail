#!/bin/sh

. ./general-utils.sh

if [ "$1" = "new" ]; then
    mime="MIME-Version: 1.0"
    content_delimiter="# content below this line (dont delete this line)"
    attachments="$(grep "Attachments: " "$2" | cut  -c 13- | tr ";" "\n")"
    start_content="$(grep "$content_delimiter" -n "$2" | head -n 1 | cut -d ":" -f 1)"
    headers="$(head -n "$((start_content - 1))" "$2" | sed '/^[[:space:]]*$/d' | grep -v "Attachments:")"

    header_boundary="$(boundary_generator)"
    mailtext_boundary="$(boundary_generator)"
    full_header="$(printf "%s\n%s\nContent-Type: multipart/mixed; boundary=\"%s\"\n" "$mime" "$headers" "$header_boundary" )"

    printf "%s\n\n" "$full_header"
    printf "%s\n" "--$header_boundary"
    printf "Content-Type: multipart/alternative; boundary=\"%s\"\n" "$mailtext_boundary"
    printf "\n%s\n" "--$mailtext_boundary"
    printf "Content-Type: text/plain; charset=\"UTF-8\"\n\n"
    tail -n +"$((start_content + 1))" "$2"
    printf "\n%s\n" "--$mailtext_boundary"
    printf "Content-Type: text/html; charset=\"UTF-8\"\n\n"
    printf "<div>\n"
    tail -n +"$((start_content + 1))" "$2" | sed ':a;N;$!ba;s/\n/<br\/>\n/g'
    printf "</div>\n"
    printf "\n%s" "--$mailtext_boundary--"
    printf "\n%s" "--$header_boundary"
    for attachment in $attachments; do
        filename="$(basename "$attachment")"
        [ ! -f "$attachment" ] && continue
        printf "\nContent-Type: text/plain; charset=\"UTF-8\"; name=\"%s\"\n" "$filename"
        printf "Content-Disposition: attachment; filename=\"%s\"\n" "$filename"
        printf "Content-Transfer-Encoding: base64\n\n"
        base64 "$attachment"
        printf "%s" "--$header_boundary"
    done
    printf "%s\n" "--"
fi

if [ "$1" = "reply" ]; then
    content_delimiter_start="# content below this line (dont delete this line)"
    content_delimiter_end="# content above this line (dont delete this line)"
    attachments="$(grep "Attachments: " "$2" | cut  -c 13- | tr ";" "\n")"
    start_new_content="$(grep "$content_delimiter_start" -n "$2" | head -n 1 | cut -d ":" -f 1)"
    end_new_content="$(grep "$content_delimiter_end" -n "$2" | head -n 1 | cut -d ":" -f 1)"
    headers="$(head -n "$((start_new_content - 1))" "$2" | sed '/^[[:space:]]*$/d' | grep -vE "(Attachments:|Old-From:|Date:)")"
    content_type_main="$(grep "Content-Type:" "$2" | head -n 1)"
    new_content_text="$(sed -n "$((start_new_content + 1)),$((end_new_content - 1))"p "$2")"
    new_content_html="$(printf "<div>\n%s</br>\n</div>\n\n" "$(sed -n "$((start_new_content + 1)),$((end_new_content - 1))"p "$2" | sed ':a;N;$!ba;s/\n/<br\/>\n/g')")"
    start_old_content="$(grep "$content_delimiter_end" -n "$2" | cut -d ":" -f 1)"

    old_from="$(grep "Old-From: " "$2" | cut -c 10-)"
    old_date="$(date -d "$(grep "Date: " "$2" | cut -c 7-)" +"%a, %b %-d, %Y at %H:%M")"
    reply_header_text="On $old_date$old_from wrote:"

    # html and text in mail and maybe attachments
    if [ "$(echo "$content_type_main" | grep "multipart/mixed")" != "" ]; then
        boundarys="$(grep -E "boundary=\".*\"" "$2" | cut -d "\"" -f 2)"
        boundarys_regex="$(echo "$boundarys" | tr "\n" "|" )"
        boundarys_regex="(${boundarys_regex%?})"
        boundary_main="$(echo "$boundarys" | head -n 1)"

        printf "%s\n\n" "$headers"
        tail -n +"$((start_old_content + 1))" "$2" | \
            awk -v boundarys_regex="$boundarys_regex" -v reply_header_text="$reply_header_text" \
                -v new_content_text="$new_content_text" -v new_content_html="$new_content_html" \
                -v boundary_main="$boundary_main" \
                'BEGIN {text_area=0; skip=0; html_area=0; text_done=0;}
                {if (match($0,"Content-Type: text/plain") && (! text_done)) {
                    print
                    text_area=1
                    skip=1
                } else if (match($0, "--" boundary_main "--$")) {
                    # prevent print
                } else if (match($0, "Content-Type: text/html")) {
                    print $0 "\n\n" new_content_html "\n\n<div>" reply_header_text "</div>\n<blockquote>"
                    html_area=1
                    skip=1
                } else if ((text_area || html_area) && match($0, "--" boundarys_regex "$")) {
                    if (html_area) print "</blockquote>"
                    print "\n" $0
                    text_area=0
                    html_area=0
                    text_done=1
                } else if (text_area) {
                    if (! skip) {
                        print "> " $0
                    } else {
                        print "\n" new_content_text "\n\n" reply_header_text "\n"
                    }
                    skip=0
                } else {
                    print
                }}'

        for attachment in $attachments; do
            filename="$(basename "$attachment")"
            [ ! -f "$attachment" ] && continue
            printf "%s" "--${boundary_main}"
            printf "\nContent-Type: text/plain; charset=\"UTF-8\"; name=\"%s\"\n" "$filename"
            printf "Content-Disposition: attachment; filename=\"%s\"\n" "$filename"
            printf "Content-Transfer-Encoding: base64\n\n"
            base64 "$attachment"
        done

        printf "%s%s\n" "--" "$boundary_main--"
        exit
    fi

    # text mail and no attachments
    if [ "$(echo "$content_type_main" | grep "text/plain")" != "" ] && [ "$(echo "$attachments" | tr -d " ")" = "" ]; then
        printf "%s\n\n" "$headers"
        printf "%s\n\n" "$new_content_text"
        printf "%s\n\n" "$reply_header_text"
        tail -n +"$((start_old_content + 1))" "$2" | awk '{print "> " $0}'
        exit
    fi

    # text mail and attachments
    if [ "$(echo "$content_type_main" | grep "text/plain")" != "" ] && [ "$(echo "$attachments" | tr -d " ")" != "" ]; then
        mime="MIME-Version: 1.0"
        header_boundary="$(boundary_generator)"
        mailtext_boundary="$(boundary_generator)"
        headers="$(head -n "$((start_new_content - 1))" "$2" | sed '/^[[:space:]]*$/d' | grep -vE "(Attachments:|Old-From:|Date:|Content-Type:)")"
        full_header="$(printf "%s\n%s\nContent-Type: multipart/mixed; boundary=\"%s\"\n" "$mime" "$headers" "$header_boundary" )"

        printf "%s\n\n" "$full_header"
        printf "%s\n" "--$header_boundary"
        printf "Content-Type: multipart/alternative; boundary=\"%s\"\n" "$mailtext_boundary"
        printf "\n%s\n" "--$mailtext_boundary"
        printf "Content-Type: text/plain; charset=\"UTF-8\"\n\n"
        printf "%s\n\n" "$new_content_text"
        printf "%s\n\n" "$reply_header_text"
        tail -n +"$((start_old_content + 1))" "$2" | awk '{print "> " $0}'
        printf "\n%s\n" "--$mailtext_boundary"
        printf "Content-Type: text/html; charset=\"UTF-8\"\n\n"
        printf "%s\n\n" "$new_content_html"
        printf "<div>\n"
        printf "%s</br>\n\n" "$reply_header_text"
        tail -n +"$((start_old_content +1))" "$2" | sed ':a;N;$!ba;s/\n/<br\/>\n/g'
        printf "</div>\n"
        printf "\n%s" "--$mailtext_boundary--"
        printf "\n%s" "--$header_boundary"
        for attachment in $attachments; do
            filename="$(basename "$attachment")"
            [ ! -f "$attachment" ] && continue
            printf "\nContent-Type: text/plain; charset=\"UTF-8\"; name=\"%s\"\n" "$filename"
            printf "Content-Disposition: attachment; filename=\"%s\"\n" "$filename"
            printf "Content-Transfer-Encoding: base64\n\n"
            base64 "$attachment"
            printf "%s" "--$header_boundary"
        done
        printf "%s\n" "--"
    fi
fi

