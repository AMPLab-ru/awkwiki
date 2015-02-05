#!/bin/sh -e

passwd_path="./awkpasswd"

test -z "$1" -o -z "$2" && \
    { echo "Provide username and password"; exit 1; }

hash=$(echo -n "$2" | sha1sum | cut -d ' ' -f 1) 

while read line; do
    username=${line%:*}
    password=${line#*:}
    test "$username" = "$1" -a "$password" = "$hash" && exit 0
done < "$passwd_path"

exit 1
