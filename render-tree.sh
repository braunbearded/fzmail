#!/bin/sh

. ./settings.sh

tmpcontent=$(mktemp -u)
tmpcounter1=$(mktemp -u)
echo 0 > "$tmpcounter1"
rep_entry="$1"
rep_content="$2"
while read -r profile; do
    id="$(echo "$profile" | awk -F "|" '{print $1}')"
    mail="$(echo "$profile" | awk -F "|" '{print $2}')"
    mail_path="$(echo "$profile" | awk -F "|" '{print $4}')"
    mail_path_length="${#mail_path}"
    echo "$(( $(cat "$tmpcounter1")+1))" > "$tmpcounter1"
    row_number="$(cat "$tmpcounter1")"
    header="$(printf "%-6s|%-3s|%-25s\n" "$row_number" "$id" "$mail")"
    header_placeholder="header_placeholder"
    printf "%s\n%s\n%s\n" "$header_placeholder" "$header" "$header_placeholder" >> "$tmpcontent"
    mdirs "$mail_path" | while read -r folder; do
        folder_short="$(echo "$folder" | cut -c "$((mail_path_length + 2))-")"
        mails="$(mlist "$mail_path/$folder_short")"
        mail_count="$(echo "$mails" | wc -l)"
        folder_format="$(echo "$folder_short" | cut -c 1-20)"
        echo "$(( $(cat "$tmpcounter1")+1))" > "$tmpcounter1"
        row_number="$(cat "$tmpcounter1")"
        formatted_row="$(printf "%-6s|%-3s|%-25s|%-22s|%s" "$row_number" "$id" "$mail" "$folder_format" "($mail_count)")"
        printf "%s\n" "$formatted_row" >> "$tmpcontent"
        if [ "$rep_entry" = "$formatted_row" ]; then
            folder_id="$row_number"
            tmpcounter2=$(mktemp -u)
            echo 0 > "$tmpcounter2"
            echo "$rep_content" | while read -r mail_folder_entry; do
                subject="$(mshow -n -q -h subject "$mail_folder_entry" | cut -c 10-29)"
                date="$(date -d "$(mshow -n -q -h date "$mail_folder_entry" | grep -oE "[0-9]+ [A-Z][a-z][a-z] [0-9][0-9][0-9][0-9] [0-9][0-9]:[0-9][0-9]")" +"%Y-%m-%d %H:%M")"
                from="$(mshow -n -q -h from "$mail_folder_entry" | cut -c 7-)"
                echo "$(( $(cat "$tmpcounter1")+1))" > "$tmpcounter1"
                row_number="$(cat "$tmpcounter1")"
                echo "$(( $(cat "$tmpcounter2")+1))" > "$tmpcounter2"
                mail_counter="$(cat "$tmpcounter2")"
                flags="$(echo "$mail_folder_entry" | grep -oE "2$flag_delimiter.*" | cut -c 3-)"
                if [ "$(echo "$flags" | grep -o "S")" = "" ]; then
                    flags="${flags}U"
                fi
                printf "%-6s|%-3s|%-25s|%-6s|%-6s|%-8s|%s|%-20s|%-20s\n" "$row_number" "$id" "$mail" "$folder_id" "$mail_counter" "$flags" "$date" "$subject" "$from" >> "$tmpcontent"
            done
            rm "$tmpcounter2"
        fi
    done
    echo "$(( $(cat "$tmpcounter1")+1))" > "$tmpcounter1"
    row_number="$(cat "$tmpcounter1")"
    printf "%-6s|%-3s|%-25s|%s\n" "$row_number" "$id" "$mail" "<New Mail>" >> "$tmpcontent"
done < "$profiles"

rm "$tmpcounter1"
pre_content="$(cat "$tmpcontent")"
rm "$tmpcontent"
max_line_length="$(echo "$pre_content" | wc -L)"
header_delimiter="$(printf "%*s" "$max_line_length" " " | tr " " "-")"
echo "$pre_content" | sed "s/$header_placeholder/$header_delimiter/"
