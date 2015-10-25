#!/bin/sh -e

. `dirname "$0"`/awki.conf

ROOT="$wiki_root"
DSTD=$ROOT/resources/images
GSOPTS="-dEPSCrop -r100 -sDEVICE=pngalpha -dGraphicsAlphaBits=4"

EQN=$(echo "$1" | sed 's/[ ][ ]*/ /g')
EQN="
.EQ
$EQN
.EN
"

SUM=$(printf "%s" "$EQN" | sha1sum | cut -d ' ' -f 1)
IMAGE=$DSTD/$SUM.png
ERRFILE="/tmp/error"
ALIGNFILE="$DSTD/align_hints.txt"

trap 'rm -f $SUM.ps $SUM.epsi $ERRFILE' EXIT INT

if [ -f "$IMAGE" ]; then
	touch $IMAGE;
	webeqn=`grep "$IMAGE" "$ALIGNFILE" | awk 'END{print $2}'`

	if [ -n "$webeqn" ] ;then
		echo ${IMAGE#$ROOT}
		echo "$webeqn"
		exit 0
	fi
fi

printf "%s" "$EQN" | iconv -futf8 -tkoi8r settings.tr - get_baseline.tr | groff -e -Tps > $SUM.ps 2>"$ERRFILE" && \
#cat "$ERRFILE" |grep -v "^webeqn:" >&2 && \
    ps2epsi $SUM.ps $SUM.epsi 2>/dev/null && \
    gs >/dev/null -dSAFER -dBATCH -dNOPAUSE $GSOPTS \
        -sOutputFile=$IMAGE $SUM.epsi

eval `cat "$ERRFILE"  | awk '/^webeqn/{print $2}'`
echo "$IMAGE $rsb" >> "$ALIGNFILE"

test -f $IMAGE && echo "${IMAGE#$ROOT}" && echo "$rsb"

