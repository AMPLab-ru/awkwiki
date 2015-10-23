#!/bin/sh -e

. `dirname "$0"`/awki.conf

ROOT="$wiki_root"
DSTD=$ROOT/resources/images
GSOPTS="-dEPSCrop -r100 -sDEVICE=pngalpha -dGraphicsAlphaBits=4"

#EQN=".EQ\nP sub n,m ( cos theta )\n.EN"
EQN=$(echo "$1" | sed 's/[ ][ ]*/ /g')
EQN="
.ps 14p
.vs 16p
.ss 24 0
.special S SS
.EQ
$EQN
.EN
.nr !w \\w'\\*(10'
.nr !c \\n[rsb]/720
.nr !y \\n[rsb]+(\\n(!c*720)
.if \\n(!y<350 \\
.	nr !c -1
.nr !z (\\n[rst]-\\n[rsb])/1000
.tm webeqn: rsb=\\n(!c
"

SUM=$(printf "%s" "$EQN" | sha1sum | cut -d ' ' -f 1)
IMAGE=$DSTD/$SUM.png
ERRFILE="/tmp/error"
HINTFILE="$DSTD/hints.txt"


trap 'rm -f $SUM.ps $SUM.epsi $ERRFILE' EXIT INT

if [ -f "$IMAGE" ]; then
	touch $IMAGE;
	webeqn=`grep "$IMAGE" "$HINTFILE" | awk 'END{print $2}'`

	test -n "$webeqn" && echo ${IMAGE#$ROOT} && \
		echo "$webeqn" && \
		exit 0;
fi

printf "%s" "$EQN" | iconv -futf8 -tkoi8r settings.tr - | groff -e -Tps > $SUM.ps 2>"$ERRFILE" && \
#cat "$ERRFILE" |grep -v "^webeqn:" >&2 && \
    ps2epsi $SUM.ps $SUM.epsi 2>/dev/null && \
    gs >/dev/null -dSAFER -dBATCH -dNOPAUSE $GSOPTS \
        -sOutputFile=$IMAGE $SUM.epsi

webeqn=`cat "$ERRFILE" | sed -n '/webeqn: rsb=/{s/.*=\(.*\)/\1/;p}'`
echo "WEBEQN = $webeqn, IMAGE = $IMAGE" >&2
echo "$IMAGE $webeqn" >> "$HINTFILE"

test -f $IMAGE && echo "${IMAGE#$ROOT}" && echo "$webeqn"

