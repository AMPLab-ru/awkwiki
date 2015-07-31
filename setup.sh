#!/bin/bash

dst_files="cgi-bin/awkpasswd.dst cgi-bin/awki.conf.dst resources/site-logo.png.dst"

for file in $dst_files ; do
	dst_name=`echo $file | sed 's/.dst$//'`
	echo "[+] Moving $file into $dst_name"
	mv $file $dst_name
done

