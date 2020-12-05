#!/bin/sh

#S=1
#U=2
#D=3
#T=4
#P=5
#R=6
#F=7
#Z=8"
#Y=9

convert_flags() {
    #$1 = to convert flags
    echo "$1" | tr "S" "1" | tr "U" "2" | tr "D" "3" | tr "T" "4" | \
        tr "P" "5" | tr "R" "6" | tr "F" "7" | tr "Z" "8" | tr "Y" "9"
}

boundary_generator() {
    head /dev/urandom | tr -dc a-z0-9 | head -c 25
}

remove_empty_lines() {
    sed "/^[[:space:]]*$/d"
}
