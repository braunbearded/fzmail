#!/bin/sh

#$1 = type
#$2 = directory to save draft
op="$1"
draft_path="$2"

if [ "$op" = "new" ] && [ -d "$draft_path" ]; then
    shift
    shift
    while [ "$1" != "" ]; do
        case $1 in
            -f) from="$2"; shift;;
            -t) to="$2"; shift;;
            -c) cc="$2"; shift;;
            -b) bcc="$2"; shift;;
            -l) flag="$2"; shift;;
            -s) subject="$2"; shift;;
            -h) other_header="$2"; shift;;
            -o) content="$2"; shift;;
        esac
        shift
    done

    content="# content below this line (dont delete this line)"
    message_id="$(mgenmid)"
    printf "To: %s\nCc: %s\nBcc: %s\nFrom: %s\nMessage-Id: %s\nAttachments:\nSubject: %s\n%s\n%s\n\n" \
        "$to" "$cc" "$bcc" "$from" "$message_id" "$subject" "$other_header" "$content" | \
        mdeliver -v -c -X"$flag" "$draft_path"
    # new_path_type="$(dirname "$new_path")"/"$(basename "$new_path")"
    # mv "$new_path" "$new_path_type" && echo "$new_path_type"
fi

if [ "$op" = "forward" ] && [ -d "$draft_path" ]; then
    original="$3"
    shift
    shift
    shift
    while [ "$1" != "" ]; do
        case $1 in
            -f) from="$2"; shift;;
            -t) to="$2"; shift;;
            -c) cc="$2"; shift;;
            -b) bcc="$2"; shift;;
            -l) flag="$2"; shift;;
            -h) other_header="$2"; shift;;
        esac
        shift
    done
    content_delimiter_start="# content below this line (dont delete this line)"
    content_delimiter_end="# content above this line (dont delete this line)"

    orig_from="$(echo "$original" | mshow -q -h from | cut -c 7-)"
    orig_date="$(echo "$original" | mshow -q -h date | cut -c 7-)"
    orig_subject="$(echo "$original" | mshow -q -h subject | cut -c 10-)"
    orig_to="$(echo "$original" | mshow -q -h to | cut -c 5-)"
    orig_cc="$(echo "$original" | mshow -q -h cc | cut -c 5-)"
    orig_bcc="$(echo "$original" | mshow -q -h bcc | cut -c 6-)"
    orig_message_id="$(echo "$original" | mshow -q -h message-id | cut -c 13-)"
    orig_reference_id="$orig_message_id $(echo "$original" | mshow -q -h references | cut -c 13-)"
    orig_content_type="$(echo "$original" | mshow -q -h content-type | cut -d ":" -f 2)"

    subject="Fwd: $orig_subject"
    header_end="$(grep -vn "." "$original" | cut -d ":" -f 1 | head -n 1)"
    message_id="$(mgenmid)"
    other_header="$(printf "Content-Type: %s\nReferences: %s\nIn-Reply-To: %s\nOld-From: %s\nOld-Date: %s\nOld-Subject: %s\nOld-To: %s\nOld-Cc: %s\nOld-Bcc: %s\nAttachments: \n%s\n" \
        "$orig_content_type" "$orig_reference_id" "$orig_message_id" "$orig_from" "$orig_date" "$orig_subject" "$orig_to" "$orig_cc" "$orig_bcc" "$other_header")"
    forward_path="$(printf "To: %s\nCc: %s\nBcc: %s\nFrom: %s\nMessage-Id: %s\nSubject: %s\n%s\n" \
        "$to" "$cc" "$bcc" "$from" "$message_id" "$subject" "$other_header" | \
        mdeliver -v -c -X"$flag" "$draft_path")"
    forward_path_type="$(dirname "$forward_path")"/forward-"$(basename "$forward_path")"
    mv "$forward_path" "$forward_path_type"

    printf "\n%s\n\n%s\n" "$content_delimiter_start" "$content_delimiter_end" >> "$forward_path_type"
    tail -n +"$header_end" "$original" >> "$forward_path_type"

    echo "$forward_path_type"
fi

if [ "$op" = "reply" ] && [ -d "$draft_path" ]; then
    original="$3"
    shift
    shift
    shift
    while [ "$1" != "" ]; do
        case $1 in
            -f) from="$2"; shift;;
            -t) to="$2"; shift;;
            -c) cc="$2"; shift;;
            -b) bcc="$2"; shift;;
            -l) flag="$2"; shift;;
            -h) other_header="$2"; shift;;
        esac
        shift
    done
    content_delimiter_start="# content below this line (dont delete this line)"
    content_delimiter_end="# content above this line (dont delete this line)"

    orig_subject="$(echo "$original" | mshow -q -h subject | cut -c 10-)"
    orig_message_id="$(echo "$original" | mshow -q -h message-id | cut -c 13-)"
    orig_reference_id="$orig_message_id $(echo "$original" | mshow -q -h references | cut -c 13-)"
    orig_content_type="$(echo "$original" | mshow -q -h content-type | cut -d ":" -f 2)"

    subject="Re: $orig_subject"
    header_end="$(grep -vn "." "$original" | cut -d ":" -f 1 | head -n 1)"
    message_id="$(mgenmid)"
    other_header="$(printf "Content-Type: %s\nReferences: %s\nIn-Reply-To: %s\nAttachments: \n%s\n" \
        "$orig_content_type" "$orig_reference_id" "$orig_message_id" "$other_header")"
    reply_path="$(printf "To: %s\nCc: %s\nBcc: %s\nFrom: %s\nMessage-Id: %s\nSubject: %s\n%s\n" \
        "$to" "$cc" "$bcc" "$from" "$message_id" "$subject" "$other_header" | \
        mdeliver -v -c -X"$flag" "$draft_path")"
    reply_path_type="$(dirname "$reply_path")"/reply-"$(basename "$reply_path")"
    mv "$reply_path" "$reply_path_type"

    printf "\n%s\n\n%s\n" "$content_delimiter_start" "$content_delimiter_end" >> "$reply_path_type"
    tail -n +"$header_end" "$original" >> "$reply_path_type"

    echo "$reply_path_type"
fi
