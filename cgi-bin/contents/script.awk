#!/usr/bin/awk -f

BEGIN {
	print "\
<div id=\"contents\">\n\
<div id=\"contents_title\">\n\
	<h2>" name "</h2>\n\
</div>"
	print "<div id=\"contents-content\">"

	max = 0
}

{
	do {
		if (/^===/) {
			getline
			while ($0 !~ /^===/)
				if (getline <= 0)
					exit
		}

		if (/^%EQ/) {
			getline
			while ($0 !~ /^%EN/)
				if (getline <= 0)
					exit
		}

		if ((n = getdepth()) >= 4 || n == 0)
			next

		trunk()
		
		if (n < max) {
			for (i = max; i > n; i--) {
				#skip unused levels
				if (list[i] == "")
					continue

				print "</" list[i] ">"
				list[i] = ""
			}
		}

		if (list[n] == "")
			print "<ol>"

		print "\t<li><a href=\"#" getlink($0) "\">" $0 "</a></li>"

		max = n
		list[n] = "ol"

	} while (getline > 0)
}

END {
	for (i = max; i > 0; i--) {
		#skip unused levels
		if (list[i] == "")
			continue

		print "</" list[i] ">"
		list[i] = ""
	}

	print "</div>"
	print "</div>"
}

function getdepth(	n)
{
	while (/^-/) {
		sub(/^-/, "")
		n++
	}

	return n
}

function trunk(		sa, i, pref, str)
{
	gsub(/''''''/, "")
	gsub(/'''/, "")
	gsub(/''/, "")
	gsub(/``/, "")

	split($0, sa, "")
	
	for (i = 1; i <= length(sa); i++) {
		if (sa[i] != "&")
			continue

		tmp = substr($0, i)

		if (match(tmp, /^&[a-z]+;/))
			continue
		if (match(tmp, /^&#[0-9]+;/))
			continue
		sa[i] = "&amp;"
	}

	tmp = ""
	for (i = 1; i <= length(sa); i++) {
		tmp = tmp sa[i]
	}
	$0 = tmp
	
	gsub(/</, "\\&lt;")
	gsub(/>/, "\\&gt;")

	gsub("^[ \t]*", "")
	gsub("[ \t]*$", "")
	gsub("[ \t]+", " ")
}

function getlink(	str)
{
	str = $0

	gsub(" ", "_", str)

	return str
}

