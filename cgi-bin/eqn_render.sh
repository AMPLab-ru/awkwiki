#!/bin/sh -e

ROOT="/var/www/wiki.amplab.ru"
IMAGES="/resources/images"
GSOPTS="-dEPSCrop -r100 -sDEVICE=pngalpha -dGraphicsAlphaBits=4"

EQN=".EQ\n$1\n.EN"
#EQN=".EQ\nP sub n,m ( cos theta )\n.EN"

SUM=$(echo $EQN | sha1sum | cut -d ' ' -f 1)

trap 'rm -f $SUM.ps $SUM.epsi' EXIT INT

test -f $ROOT$IMAGES/$SUM.png && { touch $ROOT$IMAGES/$SUM.png;
                                   echo $IMAGES/$SUM.png; exit 0; }

echo "$EQN" | iconv -futf8 -tkoi8r settings.tr - | groff -e -Tps > $SUM.ps && \
    ps2epsi $SUM.ps $SUM.epsi && \
    gs >/dev/null -dSAFER -dBATCH -dNOPAUSE $GSOPTS \
        -sOutputFile=$ROOT$IMAGES/$SUM.png $SUM.epsi

echo $IMAGES/$SUM.png

