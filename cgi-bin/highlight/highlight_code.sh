#!/bin/bash

selfdir="$(dirname $0)"
. "$selfdir/../awki.conf"

usage() {
	echo "$(basename $0) src_file [ftyp]" >&2
	exit 1
}

cleanup() {
	true
}

test $# -lt 1 && usage

src="$1"

if [ -z "$2" ]; then
	ftyp="c"
else
	ftyp="$2"
fi

vimrc="$selfdir/html_vimrc"
vim=$(which vim)

tmpname=$(mktemp)
trap 'rm -f $tmpname' EXIT INT

# run without swap file & without X connection inside pseudo-terminal
script --return -c "$vim -X -E -n -S \"$vimrc\" +\":set ft=$ftyp\" +\":TOhtml\" +\":w! $tmpname\" +\":qall!\" $src" /dev/null >/dev/null 2>&1

#cat "$tmpname"
cat "$tmpname" | awk "/^<pre id=.vimCodeElement./,/^<\/pre>/"

