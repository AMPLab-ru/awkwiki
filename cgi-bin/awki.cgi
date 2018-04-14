#!/bin/sh -e

export LANG=ru_RU.UTF-8
export PATH=/bin:/usr/bin
export AWKPATH="`dirname $0`"
export USER=$(whoami)

exec ./awki.awk

