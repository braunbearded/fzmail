#!/bin/sh

#$1 = type
#$2 = directory to save draft
op="$1"
draft_path="$2"

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

if [ "$op" = "new" ] && [ -d "$draft_path" ]; then
    message_id="$(mgenmid)"
    printf "To: %s\nCc: %s\nBcc: %s\nFrom: %s\nMessage-Id: %s\nSubject: %s\n%s\n\n%s" \
        "$to" "$cc" "$bcc" "$from" "$message_id" "$subject" "$other_header" "$content" | \
        mdeliver -v -c -X"$flag" "$draft_path"
fi
