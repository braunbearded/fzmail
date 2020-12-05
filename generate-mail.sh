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
    forward_old_header="----Forwarded message----"
    orig_from="$(echo "$original" | mshow -q -h from | cut -c 7-)"
    orig_date="$(echo "$original" | mshow -q -h date | cut -c 7-)"
    orig_subject="$(echo "$original" | mshow -q -h subject | cut -c 10-)"
    orig_to="$(echo "$original" | mshow -q -h to | cut -c 5-)"
    orig_cc="$(echo "$original" | mshow -q -h cc | cut -c 5-)"
    orig_bcc="$(echo "$original" | mshow -q -h bcc | cut -c 6-)"

    subject="Fwd: $orig_subject"
    header_end="$(grep -n "Content-Type" "$original" | cut -d ":" -f 1 | head -n 1)"
    orig_message_id="$(echo "$original" | mshow -q -h message-id | cut -c 13-)"
    message_id="$(mgenmid)"
    other_header="$(printf "%sReferences: %s\nIn-Reply-To: %s\n" "$other_header" \
        "$orig_message_id" "$orig_message_id")"
    forward_path="$(printf "To: %s\nCc: %s\nBcc: %s\nFrom: %s\nMessage-Id: %s\nSubject: %s\n%s\n" \
        "$to" "$cc" "$bcc" "$from" "$message_id" "$subject" "$other_header" | \
        mdeliver -v -c -X"$flag" "$draft_path")"
    if [ "$header_end" != "" ]; then
        tail -n +"$header_end" "$original" >> "$forward_path"
    else
        printf "%s\nFrom: %s\nDate: %s\nSubject: %s\nTo: %s\nCc: %s\nBcc: %s\n\n" \
            "$forward_old_header" "$orig_from" "$orig_date" "$orig_subject" \
            "$orig_to" "$orig_cc" "$orig_bcc" >> "$forward_path"
        echo "$original" | mshow -r >> "$forward_path"
    fi

    echo "$forward_path"
fi
