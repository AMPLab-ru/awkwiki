#!/bin/sh -e

test -z "$1" -o -z "$2" && \
    { echo "Provide username and password"; exit 1; }

hash=$(echo -n "$2" | sha1sum | cut -d ' ' -f 1) 

while read line; do
    username=${line%:*}
    password=${line#*:}
    test "$username" = "$1" -a "$password" = "$hash" && exit 0
done << EOF
admin:e5e9fa1ba31ecd1ae84f75caaa474f3a663f05f4
user:b3daa77b4c04a9551b8781d03191fe098f325e67
EOF

exit 1
