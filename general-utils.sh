#!/bin/sh

#S=1
#U=2
#D=3
#T=4
#P=5
#R=6
#F=7
#A=8"

convert_flags() {
    #$1 = to convert flags
    echo "$1" | tr "S" "1" | tr "U" "2" | tr "D" "3" | tr "T" "4" | \
        tr "P" "5" | tr "R" "6" | tr "F" "7" | tr "A" "8"
}
