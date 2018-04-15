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

	cmd = "ls " datadir
	while (cmd | getline ls_out > 0)
		if (match(ls_out, pagename_re) &&
				substr(ls_out, RSTART + RLENGTH) !~ /,v/) {
			page = substr(ls_out, RSTART, RLENGTH)
			pages[page] = 1
		}
	close(cmd)

	ctx["print_toc"] = 1
	ctx["blankln"] = 0

#	syntax["regexp"] = "handler"
	syntax["$"] = "wiki_blank"
	syntax["##"] = "wiki_reference_category"
	syntax["#"] = "wiki_format_category"
	syntax["==="] = "wiki_highlight_block"
	syntax["= "] = "wiki_print_pagename"
	syntax[" "] = "wiki_print_mono"
	syntax["-"] = "wiki_print_heading"
	syntax["\t+[1*]"] = "wiki_print_list"
	syntax["\t[^:]+[ \t]+:[ \t]+.*$"] = "wiki_format_term"

#	line_syntax["regexp"] = "handler"
	str = "\\[\\[[^\\[\\]]+\\]\\]"
	line_syntax[str] = "wiki_format_url"

	print "<p>"
}


@include "lib.awk"
@include "plugins.awk"

{
	wiki_format_marks()
}

function wiki_format_marks()
{
	for (i in syntax) {
		if ($0 !~ "^" i)
			continue

		str = syntax[i]
		@str()
		next
	}

	if (ctx["blankln"] == 1) {
		print "<p>"
		ctx["blankln"] = 0
	}

	print wiki_format_line($0)
}

function wiki_blank()
{
	ctx["blankln"] = 1
}

function wiki_reference_category(	cmd, list)
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

function wiki_format_category(	tmp)
{
	print "<br><hr>"

	sub(/^#/, "")
	split($0, sa, "|")

	tmp = ""

	for (i = 1; i <= arrlen(sa); i++) {
		sa[i] = strip_spaces(sa[i])
		if (sa[i] ~ pagename_re)
			tmp = tmp " | " page_ref_format(sa[i])
		else
			tmp = tmp " | " sa[i]
	}

	$0 = substr(tmp, 4)
	print
}

function wiki_highlight_block()
{
	if (match($0, /{[-A-Za-z0-9_]+}/))
		wiki_highlight_code()
	else
		wiki_unformatted_block()
}

# For code highlighting in
# ==={langname}
# ===
function wiki_highlight_code(		ex)
{
	langname = substr($0, RSTART + 1, RLENGTH - 2)
	langname = tolower(langname)

	ex = 0
	tmp = ""

	if (getline <= 0)
		ex = 1

	while ($0 !~ /^===$/ && !ex) {
		tmp = tmp "\n" $0
		if (getline <= 0)
			ex = 1
	}

	tmp = substr(tmp, 2)
	fname = mktemp("")
	print tmp > fname
	close(fname)

	cmd = "./highlight/highlighter.py " fname " " langname
	while (cmd | getline out)
		print out
	close(cmd)
	rmfile(fname)

	if (ex)
		exit(1)
}

# For unformated data in:
# ===
# ===
function wiki_unformatted_block()
{
	if (getline <= 0)
		exit(1)

	print "\n<div class=\"mw-highlight\">"
	print "<pre>"

	while ($0 !~ /^===$/) {
		print html_ent_format($0)
		if (getline <= 0) {
			print "</pre>"
			print "</div>"
			exit(1)
		}
	}

	print "</pre>"
	print "</div>"
}

# TODO maybe we need to insert some additional attributes into pagename
# for example author name, or something
function wiki_print_pagename(	arr, s)
{
	sub(/^= /, "")

	# parse out magic words from pagename
	while (match($0, /__[a-zA-Z0-9]+__/, arr)) {
		switch (arr[0]) {
		case "__NOTOC__":
			ctx["print_toc"] = 0
			break
		}
		s = substr($0, 1, RSTART - 1)
		s = s substr($0, RSTART + RLENGTH)
		$0 = s
	}

	$0 = strip_spaces($0)
	if (length($0) > 0)
		print "<h1>" wiki_format_line($0) "</h1>"
}

function wiki_print_mono()
{
	print "<pre>"

	do {
		print wiki_format_line($0)
		if (getline <= 0) {
			print "</pre>"
			exit(1)
		}
	} while (/^ /)

	print "</pre>"
	wiki_format_marks()
}

# For headings and horizontal line
function wiki_print_heading(	n, link)
{
	while (/^-/) {
		sub(/^-/, "")
		n++
	}

	if (n >= 4) {
		ctx["blankln"] = 0
		print "<hr>"
		return
	}

	n++

	if (ctx["print_toc"]) {
		wiki_print_content()
		ctx["print_toc"] = 0
	}

	link = $0 = strip_spaces($0)
	gsub(/ /, "_", link)
	link = rm_quotes(link)

	print "<h"n" class=\"header\" id=\"" link "\">" wiki_format_line($0) "</h"n">"
}

function wiki_print_list(	n, i, tabcount, list, tag)
{
	do {
		if (/^\t+[*]/)
			tag = "ul"
		else
			tag = "ol"

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

		#if tag on same indent din't match, close it
		if (list[tabcount, "type"] && list[tabcount, "type"] != tag) {
			print "</" list[tabcount, "type"] ">"
			list[tabcount, "type"] = ""
		}


		if (list[tabcount, "type"] == "")
			print "<" tag ">"

		sub(/^[1*]/, "")
		print "\t<li>" wiki_format_line($0) "</li>"

		list["maxlvl"] = tabcount
		list[tabcount, "type"] = tag

		if (getline <= 0) {
			for (i = list["maxlvl"]; i > 0; i--) {
				#skip unused levels
				if (list[i, "type"] == "")
					continue

				print "</" list[i, "type"] ">"
				list[i, "type"] = ""
			}
			exit(1)
		}

	} while (/^\t+[1*]/)

	for (i = list["maxlvl"]; i > 0; i--) {
		#skip unused levels
		if (list[i, "type"] == "")
			continue

		print "</" list[i, "type"] ">"
		list[i, "type"] = ""
	}
	wiki_format_marks()
}

# For Terms:
# <Tab>Term : defenition
# Requires to be in "<dl></dl>"
function wiki_format_term(	term, def)
{
	print "<dl>"

	do {
		sub(/^\t/, "", $0)
		term = $0
		sub(/[ \t]+:.*$/, "", term)

		def = $0
		sub(/[^:]+:[ \t]+/, "", def)

		term = wiki_format_line(term)
		def = wiki_format_line(def)

		print "\
		      <dt>" term "</dt>\n\
		      <dd>" def "</dd>"
		if (getline <= 0) {
			print "</dl>"
			exit(1)
		}
	} while (/\t[^:]+[ \t]+:[ \t]+.*$/)

	print "</dl>"
	wiki_format_marks()
}

function wiki_print_content(	cmd, tmp, file)
{
	print "\
<div id=\"contents\">\n\
<div id=\"contents_title\">\n\
	<h2>" contents "</h2>\n\
</div>\n\
<div id=\"contents-content\">\n\
</div></div>"
}

function wiki_format_line(fmt,		i, j, pref, suf, strong, em, code, wikilink, fun, cont)
{
	strong = em = code = 0
	wikilink = !0
	i = 1

	while (i <= length(fmt)) {
		pref = substr(fmt, 1, i - 1)
		suf = substr(fmt, i)
		tag = ""
		cont = 0

		if (suf ~ /^''''''/) {
			sub(/^''''''/, "", suf)
			wikilink = !wikilink
			fmt = pref suf
			continue
		}
		if (suf ~ /^'''/) {
			sub(/^'''/, "", suf)
			tag = (strong ? "</strong>" : "<strong>")
			strong = !strong
		} else if (suf ~ /^''/) {
			sub(/^''/, "", suf)
			tag = (em ? "</em>" : "<em>")
			em = !em
		} else if (suf ~ /^``/) {
			sub(/^``/, "", suf)
			tag = (code ? "</code>" : "<code>")
			code = !code
		}
		if (tag) {
			fmt = pref tag suf
			i += length(tag)
			continue
		}
		if (match(suf, /^https?:\/\/[^ \t]*\.(jpg|jpeg|gif|png)/)) {
			link = substr(suf, 1, RLENGTH)
			sub(/^https?:\/\/[^ \t]*\.(jpg|jpeg|gif|png)/, "", suf)

			link = "<img src=\"" link "\">"

			i += length(link)
			fmt = pref link suf
			continue
		}
		if (match(suf, /^((https?|ftp|gopher):\/\/|(mailto|news):)[^ \t]*/)) {
			link = substr(suf, 1, RLENGTH)
			sub(/^((https?|ftp|gopher):\/\/|(mailto|news):)[^ \t]*/, "", suf)

			link = "<a href=\"" link "\">" link "</a>"
			# remove mailto: in link description
			sub(/>mailto:/, ">", link)

			i += length(link)
			fmt = pref link suf
			continue
		}
		if (match(suf, /^&[a-z]+;/) || match(suf, /^&#[0-9]+;/)) {
			i += RLENGTH
			continue
		}
		if (suf ~ /^</) {
			sub(/^</, "\\&lt;", suf)
			i += 4
			fmt = pref suf
			continue
		}
		if (suf ~ /^>/) {
			sub(/^>/, "\\&gt;", suf)
			i += 4
			fmt = pref suf
			continue
		}
		if (suf ~ /^&/) {
			sub(/^&/, "&amp;", suf)
			i += length("&amp;")
			fmt = pref suf
			continue
		}
		if (match(suf, "^" pagename_re)) {
			if (wikilink) {
				link = substr(suf, 1, RLENGTH)
				sub("^" pagename_re, "", suf)

				link = page_ref_format(link)

				i += length(link)
				fmt = pref link suf
			} else
				i += RLENGTH

			continue
		}

		for (j in line_syntax) {
			if (!match(suf, "^" j))
				continue

			cont = 1

			fun = line_syntax[j]
			res = @fun(substr(suf, RSTART, RLENGTH))
			sub("^" j, "", suf)

			i += length(res)
			fmt = pref res suf
			break
		}

		if (cont == 0)
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
	split(fmt, sa, "")
	for (i = 1; i <= length(sa); i++) {
		if (sa[i] != "&")
			continue

		tmp = substr(fmt, i)

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

function wiki_format_url(fmt,	i, pref, ref, suf, n, name, link, ret, atag)
{
	if (match(fmt, /^\[\[[^\[\]]+\]\]$/)) {
		#strip square brackets
		ref = substr(fmt, 3, RLENGTH - 4)

		n = split(ref, a, "|")

		name = link = a[1]
		gsub(" ", "", link)

		if (n > 1)
			name = a[2]

		if (link ~ "^" pagename_re "$") {
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
	if (link !~ /https?:\/\/[^\t]*\.(jpg|jpeg|gif|png)/)
		return ""

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
	gsub(/"/, "\\&quot;", s)
	gsub(/&/, "\\\\&", s)
	gsub(/\[/, "\\&#91;", s)
	gsub(/\]/, "\\&#93;", s)

	gsub(/\\/, "\\\\", s)
	gsub(/&/, "\\\\&", s)

	return s
}

