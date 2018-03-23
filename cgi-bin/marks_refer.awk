#!/usr/bin/awk -f

#Ссылка на гост, под который делается оформление
#https://ru.wikisource.org/wiki/%D0%93%D0%9E%D0%A1%D0%A2_7.1%E2%80%942003

BEGIN {
	join_expr = ", "

	fmt_pref = "\n\t<li>"
	fmt_site_name = "%s [Электронный ресурс] : "
	fmt_authors = "%F %T / %A"
	fmt_q_author = "%T / %Q"
	fmt_book = " // %B"

	fmt_phys_single = " — %P %page%"
	fmt_phys_collection = " — %pages% %P"

	fmt_suf = "\n\t</li>"

	fmt_url = " — %U"
}

function fmt_string(a, s,	nsubs, tmp) {
	nsubs = 0
	for (i in a) {
		tmp = a[i]
		if (tmp == "")
			continue
		#encode special char &
		sub("&", "\\\\&", tmp)

		nsubs += sub(i, tmp, s)
	}

	if (nsubs == 0)
		return ""

	return s
}

function get_rec_lang(a,	i) {
	for (i in a) {
		if (a[i] ~ "[А-Яа-я]")
			return "RU"
	}

	return "ENG"
}

function arrlen(a,	i, x) {
	for (x in a)
		i++

	return i
}

function add_ending_dot(s) {
	if (length(s) < 1)
		return ""
	if (substr(s, length(s)) != ".")
		s = s "."

	return s
}

function fmt_issuer_section(a,	res) {
	if ("%C" in a)
		res = a["%C"]

	if ("%I" in a) {
		if (res != "")
			res = res " : "
		res = res a["%I"]
	}

	if ("%D" in a) {
		if (res != "")
			res = res ", "
		res = res a["%D"]
	}
	if (res != "")
		res = " — " res

	return res
}

function fmt_url_section(a,	res, url) {
	if ("%U" in a) {
		url = a["%U"]
		if (length(url) > 20) {
			url = substr(a["%U"], 1, 20) "..."
		}

		res = gen_href(a["%U"], url)
		res = " — " res
	}

	return res
}

function fmt_phys_section(a,    res, url) {
	if (get_rec_lang(a) == "ENG") {
		pageinfo["%page%"] = "p."
		pageinfo["%pages%"] = "pp."
	} else {
		pageinfo["%page%"] = "c."
		pageinfo["%pages%"] = "C."
	}

	if (a["%P"] ~ "—") #it's some papers collection
		res = fmt_phys_collection
	else
		res = fmt_phys_single

	res = fmt_string(pageinfo, res)

	return fmt_string(a, res)
}	

function print_ref(a,	i, str, out, tmp) {
	if (arrlen(a) == 0) {
		print ""
		return
	}

	out = fmt_pref fmt_string(a, fmt_site_name)

	if ("%Q" in a)
		out = out fmt_string(a, fmt_q_author)
	else
		out = out fmt_string(a, fmt_authors)
	
	out = add_ending_dot(out \
			     fmt_string(a, fmt_book)) \
	    add_ending_dot(fmt_issuer_section(a)) \
	    add_ending_dot(fmt_phys_section(a)) \
	    add_ending_dot(fmt_url_section(a)) \
	    fmt_suf

	#Cleanup fmt string
	gsub(/%[A-Z]+/, "", out)

	#html encode
	gsub(/\[/, "\\&#91;", out); gsub(/\]/, "\\&#93;", out);

	printf("%s\n", out)
}

function parse_authors(s, isheader,	a, initials, surname) {
	split(s, a, " ")
	surname = a[1]

	for (i = 2; i <= length(a); i++) {
		if (isheader && length(a[i]) > 2)
			a[i] = substr(a[i], 1, 1) "."

		if (initials == "")
			initials = a[i]
		else
			initials = initials " " a[i]
	}

	if (isheader == 1)
		return surname ", " initials

	return initials " " surname
}

function join_authors(s) {
	if (refentry["%NA"] == 0) {
		refentry["%A"] = parse_authors(s, 0)
		refentry["%F"] = parse_authors(s, 1)
	} else {
		refentry["%A"] = refentry["%A"] join_expr parse_authors(s, 0)
	}
	refentry["%NA"] += 1
}

function ref_fmt() {
	delete refentry
	print "<ol>"

	while(getline > 0) {
		if (/^%R\)/) {
			print_ref(refentry)
			print "</ol>"
			next
		} else if (/^$/){
			print_ref(refentry)
			delete refentry
			continue
		} else if (/^[^%]/ || /^$/) {
			continue
		}

		tag = $1
		gsub(/^[^ ]+[ ]+/, "")

		if (tag == "%A") {
			join_authors($0)
			continue
		}

		if (tag == "%P")
			sub("-", "—")

		refentry[tag] = $0
	}
}

