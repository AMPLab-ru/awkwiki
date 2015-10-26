#!/bin/sh -e

. `dirname "$0"`/awki.conf

ROOT="$wiki_root"
DSTD="$ROOT/resources/images"
GSOPTS="-dEPSCrop -r100 -sDEVICE=pngalpha -dGraphicsAlphaBits=4"

EQN=$(echo "$1" | sed 's/[ ][ ]*/ /g')
EQN="
.EQ
$EQN
.EN
"

SUM=$(printf "%s" "$EQN" | sha1sum | cut -d ' ' -f 1)
IMAGE="$DSTD/$SUM.png"
ERRFILE="/tmp/awki_groff_error"
ALIGNFILE="${IMAGE}.sty"

trap 'rm -f $SUM.ps $SUM.eps $ERRFILE' EXIT INT

if test -f "$IMAGE"; then
	touch "$IMAGE";

	if test -n "$ALIGNFILE"; then
		echo "${IMAGE#$ROOT}"
		cat "$ALIGNFILE"
		exit 0
	fi
fi

printf "%s" "$EQN" | iconv -futf8 -tkoi8r settings.tr - get_baseline.tr | groff -e -Tps > "$SUM.ps" 2> "$ERRFILE" && \
    (cat "$ERRFILE" |grep -v "^webeqn:" >&2; true) && \
    ps2eps "$SUM.ps" 2>/dev/null && \
    gs >/dev/null -dSAFER -dBATCH -dNOPAUSE $GSOPTS \
        -sOutputFile=$IMAGE $SUM.eps

eval `awk '/^webeqn/ { print $2 }' "$ERRFILE"`
echo "$rsb" > "$ALIGNFILE"

test -f "$IMAGE" && echo "${IMAGE#$ROOT}" && echo "$rsb"

