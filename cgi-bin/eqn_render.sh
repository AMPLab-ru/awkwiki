#!/bin/sh -e

. `dirname "$0"`/awki.conf

ROOT="$wiki_root"
DSTD=$ROOT/resources/images
GSOPTS="-dEPSCrop -r100 -sDEVICE=pngalpha -dGraphicsAlphaBits=4"

#EQN=".EQ\nP sub n,m ( cos theta )\n.EN"
EQN=$(echo "$1" | sed 's/[ ][ ]*/ /g')
EQN=".EQ\n$EQN\n.EN"

SUM=$(echo $EQN | sha1sum | cut -d ' ' -f 1)
IMAGE=$DSTD/$SUM.png

trap 'rm -f $SUM.ps $SUM.epsi' EXIT INT

test -f $IMAGE && { touch $IMAGE; echo ${IMAGE#$ROOT}; exit 0; }

echo "$EQN" | iconv -futf8 -tkoi8r settings.tr - | groff -e -Tps > $SUM.ps && \
    ps2epsi $SUM.ps $SUM.epsi 2>/dev/null && \
    gs >/dev/null -dSAFER -dBATCH -dNOPAUSE $GSOPTS \
        -sOutputFile=$IMAGE $SUM.epsi

test -f $IMAGE && echo ${IMAGE#$ROOT}

