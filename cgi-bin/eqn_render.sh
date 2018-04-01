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
IMAGE="$DSTD/$SUM.svg"
ERRFILE="/tmp/awki_groff_error"
ALIGNFILE="${IMAGE}.sty"

trap 'rm -f /tmp/$SUM.ps /tmp/$SUM.eps $ERRFILE' EXIT INT

if test -f "$IMAGE"; then
	touch "$IMAGE";

	if test -n "$ALIGNFILE"; then
		echo "${IMAGE#$ROOT}"
		cat "$ALIGNFILE"
		exit 0
	fi
fi

printf "%s" "$EQN" | \
    iconv -futf8 -tkoi8r $ROOT/cgi-bin/settings.tr - $ROOT/cgi-bin/get_baseline.tr	| \
    groff -e -Tps 2>&1 > "/tmp/$SUM.ps" | \
    tee "$ERRFILE" | \
    awk '$0 !~ /^webeqn/'>&2
ps2eps -f "/tmp/$SUM.ps" >/dev/null 2>&1
epstopdf "/tmp/$SUM.eps" >/dev/null 2>&1
pdf2svg /tmp/$SUM.pdf $IMAGE
#gs >/dev/null -dSAFER -dBATCH -dNOPAUSE $GSOPTS \
#    -sOutputFile=$IMAGE /tmp/$SUM.eps

eval `awk '/^webeqn/ { print $2 }' "$ERRFILE"`
echo "$rsb" > "$ALIGNFILE"

test -f "$IMAGE" && echo "${IMAGE#$ROOT}" && echo "$rsb"

