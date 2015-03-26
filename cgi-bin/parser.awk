#!/usr/bin/awk -bf
################################################################################
# parser.awk - parsing script for awkiawki
# $Id: parser.awk,v 1.6 2002/12/07 13:46:45 olt Exp $
################################################################################
# Copyright (c) 2002 Oliver Tonnhofer (olt@bogosoft.com)
# See the file `COPYING' for copyright notice.
################################################################################

BEGIN {
	pagename_re = "[[:upper:]][[:lower:]]+[[:upper:]][[:alpha:]]*"
	list["ol"] = 0
	list["ul"] = 0
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

# register blanklines
/^$/ { blankline = 1; close_tags(); next }

# HTML entities for <, > and &
/[&<>]/ { gsub(/&/, "\\&amp;");	gsub(/</, "\\&lt;"); gsub(/>/, "\\&gt;") }

# generate links
pagename_re || /(https?|ftp|gopher|mailto|news):/ {
	tmpline = ""
	for (i = 1; i <= NF; i++) {
		field = $i 
		# generate HTML img tag for .jpg,.jpeg,.gif,png URLs
		if (field ~ /https?:\/\/[^\t]*\.(jpg|jpeg|gif|png)/ \
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

# embedded eqn
/\$\$[^\$]*\$\$/ {
	while (match($0, /\$\$[^\$]*\$\$/)) {
		eqn = substr($0, RSTART, RLENGTH)
		gsub(/\$\$/, "", eqn)
		# the last gsub() is very important, alt is used in sub() below
		alt = eqn; gsub(/"/, "\\&quot;", alt); gsub(/&/, "\\\\&", alt)

		eqn = unescape(eqn)
		image = eqn_gen_image(eqn)
		sub(/\$\$[^\$]*\$\$/, "<img alt=\"" alt "\" src=\"" image "\">")
	}
}

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

/^%EQ$/, /^%EN$/ {
	if (/^%EQ$/) {
		eqn = ""; next
	}

	if (/^%EN$/) {
		alt = eqn; gsub(/"/, "\\&quot;", alt)

		eqn = unescape(eqn)
		image = eqn_gen_image(eqn)
		if (blankline == 1) {
			print "<p>"; blankline = 0
		}
		print "<img style=\"margin-left:2em;\" alt=\"" alt "\" src=\"" image "\">"; next
	}

	eqn = eqn ? eqn "\n" $0 : $0; next
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
		if (list["ol"] > 0) {
			parse_list("ol", "ul")
		} else if (list["ul"] > 0) {
			parse_list("ul", "ol")
		} 
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

function parse_list(this, other)
{
	thislist = list[this]
	otherlist = list[other]
	tabcount = 0

	while (/^\t+[1*]/) {
		sub(/^\t/,"")
		tabcount++
	}
	
	# close foreign tags
	if (otherlist > 0) {
		while (otherlist-- > 0) {
			print "</" other ">"
		}
	}

	# if we are needing more tags we open new
	if (thislist < tabcount) {
		while (thislist++ < tabcount) {
			print "<" this ">"
		}
	# if we are needing less tags we close some
	} else if (thislist > tabcount) {
		while (thislist-- != tabcount) {
			print "</" this ">"
		}
	}

	if (tabcount) {
		sub(/^[1*]/, "")
		$0 = "\t<li>" $0
	}
	
	list[other] = 0
	list[this] = tabcount
}

