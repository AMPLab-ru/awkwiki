#!/usr/bin/awk -f
################################################################################
# parser.awk - parsing script for awkiawki
# $Id: parser.awk,v 1.6 2002/12/07 13:46:45 olt Exp $
################################################################################
# Copyright (c) 2002 Oliver Tonnhofer (olt@bogosoft.com)
# See the file `COPYING' for copyright notice.
################################################################################

@include "lib.awk"

BEGIN {
	pagename_re = "[[:upper:]][[:lower:]]+[[:upper:]][[:alpha:]]*"
	list["maxlvl"] = 0
	scriptname = ENVIRON["SCRIPT_NAME"]

	cmd = "ls " datadir
	while (cmd | getline ls_out > 0)
		if (match(ls_out, pagename_re) &&
				substr(ls_out, RSTART + RLENGTH) !~ /,v/) {
			page = substr(ls_out, RSTART, RLENGTH)
			pages[page] = 1
		}
	close(cmd)
}

@include "./marks_refer.awk"

NR == 1 { print "<p>" }

{
	if (/^$/) {
		blankline = 1
		close_tags()
		next
	} else if (/^##$/) {
		close_tags()
		category_reference()
		next
	} else if (/^#/) {
		close_tags()
		sub(/^# */, "")

		category_format()
		next
	} else if (/^%R/) {
		ref_fmt()
	} else if (/^%EQ$/) {
		tmp = ""

		while (getline > 0 && $0 !~ /^%EN$/)
			tmp = tmp "\n" $0

		tmp = substr(tmp, 2)

		if (blankline) {
			blankline = 0
			print "<p>"
		}

		print eqn_gen_image(tmp)
		next
	} else if (/^===/) {
		close_tags()

		if (match($0, /{[-A-Za-z0-9_]+}/))
			code_highlight()
		else
			non_format()

		next
	} else if (/^ /) {
		close_tags("pre")

		if (pre != 1) {
			print "<pre>"
			pre = 1
			blankline = 0
		} else if (blankline == 1) {
			print ""
			blankline = 0
		}

		$0 = all_format($0)

		print
		next
	} else if (/^-/) {
		heading_format()
		next
	} else if (/^\t+[*]/) {
		close_tags("list")
		$0 = all_format($0)
		parse_list("ul", "ol")
		print
		next
	} else if (/^\t+[1]/) {
		close_tags("list")
		$0 = all_format($0)
		parse_list("ol", "ul")
		print
		next
	} else if (/\t[^:][^:]*[ \t]+:[ \t]+.*$/) {
		close_tags("dl")
		sub(/^\t/, "")

		term = $0
		sub(/[ \t]+:.*$/, "", term)

		def = $0
		sub(/[^:][^:]*:[ \t]+/, "", def)

		if (dl != 1) {
			print "<dl>"; dl = 1
		}

		print "<dt>" term "</dt>"
		print "\t<dd>" def "</dd>"
		next
	} else if (/^\{\|/) {
		sub(/^\{\|[\ ]*/, "")

		print "<div align=\"" $0 "\">\n<table class=\"table\">"
		print_tbl()
		print "</table>\n</div>"

		next
	}

	close_tags()

	if (blankline == 1) {
		print "<p>"
		blankline = 0
	}

	$0 = all_format($0)

	print
}

END {
	$0 = ""
	close_tags()
}

function print_tbl(i, j, attr, cattr, cells, colspan, rowspan)
{
	print "<tr>"

	while (getline > 0 && $0 !~ /^\|\}$/) {
		if (/^\|--/)
			print "</tr><tr>"
		else if (/^\|/) {
			j = split($0, cells, /\ *\|\ */)

			for (i = 2; i <= j; ++i) {
				match(cells[i], /^[^\ ]+!/)
				cattr = substr(cells[i], RSTART, RLENGTH - 1)
				sub(/^[^\ ]+!\ */, "", cells[i])

				attr = "class=\"table"
				attr = attr (cattr ~ /h/ ? " head" : "") "\""

				if (cattr ~ /l/)
					attr = attr " align=\"left\""
				else if (cattr ~ /c/)
					attr = attr " align=\"center\""
				else if (cattr ~ /r/)
					attr = attr " align=\"right\""

				if (match(cattr, /[1-9]{2}/)) {
					colspan=substr(cattr, RSTART, 1)
					rowspan=substr(cattr, RSTART + 1, 1)
					attr = attr " colspan=\"" colspan "\""
					attr = attr " rowspan=\"" rowspan "\""
				}

				cells[i] = all_format(cells[i])
				print "<td " attr ">"  cells[i] "</td>"
			}
		}
	}

	print "</tr>"
}

function all_format(fmt,	i, pref, tmp, suf, strong, em, code, wikilink)
{
	split(fmt, sa, "")
	strong = em = code = 0
	wikilink = !0
	i = 1

	while (i <= length(fmt)) {

		pref = substr(fmt, 1, i - 1);
		tmp = substr(fmt, i);

		if (tmp ~ /^''''''/) {
			sub(/^''''''/, "", tmp)

			fmt = pref tmp

			wikilink = !wikilink
			split(fmt, sa, "")
			continue
		}
		if (tmp ~ /^'''/) {
			sub(/^'''/, "", tmp)

			fmt = pref (strong ? "</strong>" : "<strong>") tmp
			i += (strong ? length("</strong>") : length("<strong>"))

			strong = !strong
			split(fmt, sa, "")
			continue
		}
		if (tmp ~ /^''/) {
			sub(/^''/, "", tmp)

			fmt = pref (em ? "</em>" : "<em>") tmp
			i += (em ? length("</em>") : length("<em>"))

			em = !em
			split(fmt, sa, "")
			continue
		}
		if (tmp ~ /^``/) {
			sub(/^``/, "", tmp)

			fmt = pref (code ? "</code>" : "<code>") tmp
			i += (code ? length("</code>") : length("<code>"))

			code = !code
			split(fmt, sa, "")
			continue
		}
		if (match(tmp, /^\$\$[^\$]*\$\$/)) {
			suf = substr(tmp, RLENGTH + 1)
			eqn = substr(tmp, 3, RLENGTH - 4)

			img = eqn_gen_image(eqn)

			fmt = pref img suf
			split(fmt, sa, "")
			i += length(img)
			continue
		}
		if (match(tmp, /^\[\[[^\[\]]+\]\]/)) {
			link = wiki_url_format(substr(tmp, RSTART, RLENGTH))
			sub(/^\[\[[^\[\]]+\]\]/, "", tmp)

			i += length(link)
			fmt = pref link tmp
			split(fmt, sa, "")
			continue
		}
		if (match(tmp, /^https?:\/\/[^ \t]*\.(jpg|jpeg|gif|png)/)) {
			link = substr(tmp, 1, RLENGTH)
			sub(/^https?:\/\/[^ \t]*\.(jpg|jpeg|gif|png)/, "", tmp)

			link = "<img src=\"" link "\">"

			i += length(link)
			fmt = pref link tmp
			split(fmt, sa, "")
			continue
		}
		if (match(tmp, /^((https?|ftp|gopher):\/\/|(mailto|news):)[^ \t]*/)) {
			link = substr(tmp, 1, RLENGTH)
			sub(/^((https?|ftp|gopher):\/\/|(mailto|news):)[^ \t]*/, "", tmp)

			link = "<a href=\"" link "\">" link "</a>"
			# remove mailto: in link description
			sub(/>mailto:/, ">", link)

			i += length(link)
			fmt = pref link tmp
			split(fmt, sa, "")
			continue
		}
		if (match(tmp, "^" pagename_re)) {
			if (wikilink) {
				link = substr(tmp, 1, RLENGTH)
				sub("^" pagename_re, "", tmp)

				link = page_ref_format(link)

				i += length(link)
				fmt = pref link tmp
				split(fmt, sa, "")
				continue
			}
			else {
				i += RLENGTH
				continue
			}
		}
		if (match(tmp, /^&[a-z]+;/) || match(tmp, /^&#[0-9]+;/)) {
			i += RLENGTH
			continue
		}
		if (tmp ~ /^</) {
			sub(/^</, "\\&lt;", tmp)
			i += 4
			fmt = pref tmp
			split(fmt, sa, "")
			continue
		}
		if (tmp ~ /^>/) {
			sub(/^>/, "\\&gt;", tmp)
			i += 4
			fmt = pref tmp
			split(fmt, sa, "")
			continue
		}
		if (tmp ~ /^&/) {
			sub(/^&/, "&amp;", tmp)
			i += length("&amp;")
			fmt = pref tmp
			split(fmt, sa, "")
			continue
		}

		i += 1
	}

	if (strong)
		fmt = fmt "</strong>"
	if (em)
		fmt = fmt "</em>"
	if (code)
		fmt = fmt "</code>"

	return fmt
}

function page_ref_format(link)
{
	if (pages[link])
		return "<a href=\""scriptname"/"link"\">"link"</a>"
	else
		return link"<a href=\""scriptname"/"link"\">?</a>"
}

# HTML entities for <, > and &
function html_ent_format(fmt,	sa, tmp)
{
	#skip already escaped stuff
	split(fmt, sa, "");
	for (i = 1; i <= length(sa); i++) {
		if (sa[i] != "&")
			continue

		tmp = substr(fmt, i);

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
	fmt = tmp
	
	gsub(/</, "\\&lt;", fmt)
	gsub(/>/, "\\&gt;", fmt)

	return fmt
}

function wiki_url_format(fmt,	pref, ref, suf, n, name, link, ret, atag)
{
	if (match(fmt, /^\[\[[^\[\]]+\]\]$/)) {
		#strip square brackets
		ref = substr(fmt, 3, RLENGTH - 4)

		n = split(ref, a, "|")

		name = link = a[1]

		if (n > 1)
			name = a[2]

		if (link ~ pagename_re) {
			if (pages[link])
				return "<a href=\""scriptname"/"link"\">"name"</a>"
			else
				return name"<a href=\""scriptname"/"link"\">?</a>"
		}

		if (link !~ /^((https?|ftp|gopher|file):\/\/|(mailto|news):)/)
			link = "http://" link

		if (n > 2)
			img_options["width"] = a[3]

		ret = shape_link_image(link)

		delete img_options

		#Its image!
		if (ret != "") {
			fmt = pref ret
		} else {
		#other case
			atag = gen_href(link, name)
			fmt = pref atag
		}
	}

	return fmt
}

function shape_link_image(link,		options)
{
	if (link !~ /https?:\/\/[^\t]*\.(jpg|jpeg|gif|png)/ \
	    || link ~ /https?:\/\/[^\t]*\.(jpg|jpeg|gif|png)''''''/) {
		return ""
	}

	options = ""
	for (item in img_options)
		options = options sprintf("%s=\"%s\" ", item, img_options[item])

	link = sprintf("<img %ssrc=\"%s\">", options, link)
	return link
}

function gen_href(link, text)
{
	s = sprintf("<a href=\"%s\">%s</a>",
	    html_escape(link),
	    html_escape(text))
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

function eqn_gen_image(eqn,	cmd, image, alt, align_property)
{
	alt = eqn
	sub(/^[ \t]*/, "", s); sub(/[ \t]*$/, "", s)

	cmd = "./eqn_render.sh '" eqn "'"
	cmd | getline image;
	cmd | getline align_property;
	close(cmd);
	#printf("awk offset is %s image is '%s'\n", align_property, image)
	if (align_property == "")
		align_property = "0"

	img = sprintf("<img alt=\"%s\" src=\"%s\" " \
		      "style=\"vertical-align:%spx\">",
		      html_escape(alt), image, align_property)
	return img
}

# For code highlighting in
# ==={langname}
# ===
function code_highlight()
{
	langname = substr($0, RSTART + 1, RLENGTH - 2)
	langname = tolower(langname)

	tmp = ""

	while (getline > 0 && $0 !~ /^===$/)
		tmp = tmp "\n" $0

	tmp = substr(tmp, 2)
	fname = mktemp("")
	print tmp > fname
	close(fname)

	cmd = "./highlight/highlighter.py " fname " " langname
	while (cmd | getline out)
		print out
	close(cmd)
	rmfile(fname)
}

# For unformated data in:
# ===
# ===
function non_format()
{
	print "\n<div class=\"mw-highlight\">"
	print "<pre>"

	while (getline > 0 && $0 !~ /^===$/) {
		$0 = html_ent_format($0)
		print
	}

	print "</div>"
	print "</pre>"
}

function category_format(	tmp)
{
	print "<br><hr>"
	split($0, sa, "|")

	tmp = ""

	for (i = 1; i <= arrlen(sa); i++) {
		sub(/^ */, "", sa[i])
		sub(/ *$/, "", sa[i])
		if (sa[i] ~ pagename_re)
			tmp = tmp " | " page_ref_format(sa[i])
		else
			tmp = tmp " | " sa[i]
	}

	$0 = substr(tmp, 4)
	print
}

# For headings and horizontal line
function heading_format(	n)
{
	close_tags()

	while (/^-/) {
		sub(/^-/, "")
		n++
	}

	if (n >= 4) {
		blankline = 1
		print "<hr>"
		return
	}

	n += 1

	$0 = all_format($0)
	$0 = "<h" n ">" $0 "</h" n ">"
	print
}

