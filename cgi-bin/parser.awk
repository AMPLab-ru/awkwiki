#!/usr/bin/awk -f
################################################################################
# parser.awk - parsing script for awkiawki
# $Id: parser.awk,v 1.6 2002/12/07 13:46:45 olt Exp $
################################################################################
# Copyright (c) 2002 Oliver Tonnhofer (olt@bogosoft.com)
# See the file `COPYING' for copyright notice.
################################################################################

BEGIN {
	pagename_re = "[[:upper:]][[:lower:]]+[[:upper:]][[:alpha:]]*"
	list["maxlvl"] = 0
	scriptname = ENVIRON["SCRIPT_NAME"]
	FS = "[ ]"
	
	cmd = "ls " datadir
	while (cmd | getline ls_out > 0)
		if (match(ls_out, pagename_re) &&
		    substr(ls_out, RSTART + RLENGTH) !~ /,v/) {
			page = substr(ls_out, RSTART, RLENGTH)
			pages[page] = 1
		}
	close(cmd)
}

# HTML entities for <, > and &
/[&<>]/ {
	#skip already escaped stuff
	split($0, sa, "");
	for (i = 1; i < length(sa); i++) {
		if (sa[i] != "&")
			continue

		tmp = substr($0, i);

		if (match(tmp, /^&[a-z]+;/))
			continue
		if (match(tmp, /^&#[0-9]+;/))
			continue
		sa[i] = "&amp;"
	}

	tmp = ""
	for (i = 1; i < length(sa); i++) {
		tmp = tmp sa[i]
	}
	$0 = tmp
	
	gsub(/</, "\\&lt;");
	gsub(/>/, "\\&gt;")
}

/^%NF$/ {
	print "\n<div class=\"mw-highlight\">"
	print "<pre>";
	in_nf = 1;
	next 
}

/^%NE$/ {
	print "</div>"
	print "</pre>";
	in_nf = 0;
	next
}

in_nf == 1 {print $0; next}

/^%EQ$/, /^%EN$/ {
	if (/^%EQ$/) {
		eqn = ""; next
	}

	if (/^%EN$/) {
		alt = eqn;

		eqn = unescape(eqn)
		image = eqn_gen_image(eqn)
		if (blankline == 1) {
			print "<p>"; blankline = 0
		}
		print "<img style=\"margin-left:2em;\" alt=\"" html_escape(alt) "\" src=\"" image "\">"; next
	}

	eqn = eqn ? eqn "\n" $0 : $0; next
}

/^##$/ {
	close_tags()
	category_reference()
	next
}

/^#/ {
	close_tags()
	sub(/^# */, "")
	print "<br><hr>"; print
	next
}

# register blanklines
/^$/ { blankline = 1; close_tags(); next }

# embedded eqn
/\$\$[^\$]*\$\$/ {
	while (match($0, /\$\$[^\$]*\$\$/)) {
		eqn = substr($0, RSTART, RLENGTH)
		gsub(/\$\$/, "", eqn)
		# the last gsub() is very important, alt is used in sub() below
		alt = eqn;
		eqn = unescape(eqn)
		image = eqn_gen_image(eqn)
		sub(/\$\$[^\$]*\$\$/, "<img alt=\"" html_escape(alt) "\" src=\"" image "\">")
	}
}

#[http://url.com|some name]
/\[/ {
	while (match($0, /\[[^\[\]]+\]/)) {

		#strip square brackets
		pref = substr($0, 1, RSTART - 1)
		ref = substr($0, RSTART + 1, RLENGTH - 2)
		suf = substr($0, RSTART + RLENGTH)

		n = split(ref, a, "|")

		name = link = a[1]
		if (link !~ /^((https?|ftp|gopher):\/\/|(mailto|news):)/ &&
		    link !~ pagename_re)
			link = "http://" link

		if (n > 1)
			name = a[2]

		atag = sprintf("<a href=\"%s\"> %s </a> ", link, name)
		$0 = pref atag suf
	}
}

# generate links
pagename_re || /(https?|ftp|gopher|mailto|news):/ || /\[/ {
	tmpline = ""
	for (i = 1; i <= NF; i++) {
		field = $i 

		#skip already generated links
		if (field ~ /<a/) {
			tmp = field
			for (j = i + 1; j <= NF; j++) {
				tmp = tmp " " $j
				if ($j ~ "</a>") {
					i = j
					field = tmp
					break
				}
			}
		# generate HTML img tag for .jpg,.jpeg,.gif,png URLs
		} else if (field ~ /https?:\/\/[^\t]*\.(jpg|jpeg|gif|png)/ \
			&& field !~ /https?:\/\/[^\t]*\.(jpg|jpeg|gif|png)''''''/) {
			sub(/https?:\/\/[^\t]*\.(jpg|jpeg|gif|png)/, "<img src=\"&\">", field)
		# links for mailto, news and http, ftp and gopher URLs
		} else if (field ~ /((https?|ftp|gopher):\/\/|(mailto|news):)[^\t]*/) {
			sub(/((https?|ftp|gopher):\/\/|(mailto|news):)[^\t]*[^.,?;:'")\t]/, "<a href=\"&\">&</a>", field)
			# remove mailto: in link description
			sub(/>mailto:/, ">",field)
		# links for awkipages
#} else if (field ~ /(^|[[,.?;:'"\(\t])[[:upper:]][[:lower:]]+[[:upper:]][[:alpha:]]*/ && field !~ /''''''/) {
		} else if (field ~ pagename_re && field !~ /''''''/) {
			match(field, pagename_re)
			tmp_pagename = substr(field, RSTART, RLENGTH)
			if (pages[tmp_pagename])
				sub(pagename_re, "<a href=\""scriptname"/&\">&</a>", field)
			else
				sub(pagename_re, "&<a href=\""scriptname"/&\">?</a>", field)
		}
		tmpline = tmpline field OFS
	}
	# return tmpline to $0 and remove last OFS (whitespace)
	$0 = substr(tmpline, 1, length(tmpline) - 1)
}

# remove six single quotes (Wiki''''''Links)
{ gsub(/''''''/, "") }


# emphasize text in single-quotes 
/'''/ { gsub(/'''('?'?[^'])*'''/, "<strong>&</strong>"); gsub(/'''/, "") }
/''/  { gsub(/''('?[^'])*''/, "<em>&</em>"); gsub(/''/, "") }
/``/  { gsub(/``(`?[^`])*```*/, "<code>&</code>"); gsub(/``/, "") }


# headings
/^-[^-]/ { $0 = "<h2>" substr($0, 2) "</h2>"; close_tags(); print; next }
/^--[^-]/ { $0 = "<h3>" substr($0, 3) "</h3>"; close_tags(); print; next }
/^---[^-]/ { $0 = "<h4>" substr($0, 4) "</h4>"; close_tags(); print; next }

# horizontal line
/^----/ { sub(/^----+/, "<hr>"); blankline = 1; close_tags(); print; next }

/^\t+[*]/ { close_tags("list"); parse_list("ul", "ol"); print; next }
/^\t+[1]/ { close_tags("list"); parse_list("ol", "ul"); print; next }

# definitions
/\t[^:][^:]*[ \t]+:[ \t]+.*$/ {
	close_tags("dl")
	sub(/^\t/, "")
	term = $0; sub(/[ \t]+:.*$/, "", term)
	def = $0; sub(/[^:][^:]*:[ \t]+/, "", def)

	if (dl != 1) {
		print "<dl>"; dl = 1
	}
	
	print "<dt>" term "</dt>" 
	print "\t<dd>" def "</dd>" 
	next
}

/^ / { 
	close_tags("pre");
	if (pre != 1) {
		print "<pre>\n" $0; pre = 1
		blankline = 0
	} else { 
		if (blankline == 1) {
			print ""; blankline = 0
		}
		print
	}
	next
}

NR == 1 { print "<p>" }

{
	close_tags()
	
	# print paragraph when blankline registered
	if (blankline == 1) {
		print "<p>"; blankline = 0
	}

	print
}

END {
	$0 = ""
	close_tags()
}

function eqn_gen_image(s,	cmd, image)
{
	sub(/^[ \t]*/, "", s); sub(/[ \t]*$/, "", s)

	cmd = "./eqn_render.sh '" s "'"
	cmd | getline image; close(cmd)
	return image
}

function unescape(s)
{
	gsub(/&amp;/, "\\&", s); gsub(/&lt;/, "<", s); gsub(/&gt;/, ">", s)
	return s
}

function html_escape(s) {
	gsub(/"/, "\\&quot;", s);
	gsub(/&/, "\\\\&", s);
	gsub(/\[/, "\\&#91;", s);
	gsub(/\]/, "\\&#93;", s);

	gsub(/\\/, "\\\\", s);
	gsub(/&/, "\\\\&", s);

	return s
}

function category_reference(	cmd, list)
{
	cmd = "grep -wl '^#.*" pagename "' " datadir "*"

	while (cmd | getline > 0) {
		if (!list) { list = 1; print "<p><ul>" }
		sub(/^.*[^\/]\//, "")
		sub(pagename_re, "<li><a href=\""scriptname"/&\">&</a></li>")
		print
	}

	if (list)
		print "</ul>"

	close(cmd)
}

function close_tags(not)
{
	# if list is parsed this line print it
	if (not !~ "list") {
		parse_list("ol", "ul")
	}
	# close monospace
	if (not !~ "pre") {
		if (pre == 1) {
			print "</pre>"; pre = 0
		}
	}
	# close dl
	if (not !~ "dl") {
		if (dl == 1) {
			print "</dl>"; dl = 0
		}
	}
}

function parse_list(this, other,	n, i)
{
	thislist = list[this]
	otherlist = list[other]
	tabcount = 0

	while (/^\t+[1*]/) {
		sub(/^\t/,"")
		tabcount++
	}

	#close foreign tags in reverse order
	if (tabcount < list["maxlvl"]) {
		for (i = list["maxlvl"]; i > tabcount; i--) {
			#skip unused levels
			if (list[i, "type"] == "")
				continue

			print "</" list[i, "type"] ">"
			list[i, "type"] = ""
		}
	}

	if (!tabcount)
		return

	#if tag on same indent din't match, close it
	if (tabcount && list[tabcount, "type"] &&
	    list[tabcount, "type"] != this) {
		#close this tag
		print "</" list[tabcount, "type"] ">"
		list[tabcount, "type"] = ""
	}


	if (list[tabcount, "type"] == "")
		print "<" this ">"
	
	sub(/^[1*]/, "")
	$0 = "\t<li>" $0 "</li>"

	list["maxlvl"] = tabcount
	list[tabcount, "type"] = this

	return
}

