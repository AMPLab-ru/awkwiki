#!/usr/bin/awk -f

BEGIN {
	join_expr = ", "

	fmt_authors = "\t1 %F %T / %A"
	fmt_q_author = "\t1 %T / %Q"
	fmt_book = " // %B"
	fmt_issuer = " — %C %I %D"

	fmt_phys_eng = " — %P p."
	fmt_phys_single = " — %P с."
	fmt_phys_collection = " — C. %P"

	fmt_url = " — %U"
}

function fmt_string(a, s,	nsubs, tmp) {
	nsubs = 0
	for (i in a) {
		#encode special char &
		tmp = a[i]
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

function print_ref(a,	i, str, out, tmp) {
	if (arrlen(a) == 0) {
		print ""
		return
	}

	if ("%Q" in a)
		out = fmt_string(a, fmt_q_author)
	else
		out = fmt_string(a, fmt_authors)

	if (get_rec_lang(a) == "ENG")
		fmt_phys_info = fmt_phys_eng
	else if ("%B" in a) #it's some papers collection
		fmt_phys_info = fmt_phys_collection
	else
		fmt_phys_info = fmt_phys_single

	out = add_ending_dot(out \
			     fmt_string(a, fmt_book)) \
	    add_ending_dot(fmt_issuer_section(a)) \
	    add_ending_dot(fmt_string(a, fmt_phys_info)) \
	    add_ending_dot(fmt_string(a, fmt_url))

	#Cleanup fmt string
	gsub(/%[A-Z]+/, "", out)
	
	printf("%s\n", out)
}

function parse_authors(s, is_header,	a, initials, surname) {
	split(s, a, " ")
	surname = a[1]

	for (i = 2; i <= length(a); i++) {
		if (is_header && length(a[i]) > 2)
			a[i] = substr(a[i], 1, 1) "."

		initials = initials " " a[i]
	}

	if (is_header == 1)
		return surname "," initials

	return initials " " surname
}

#function parse_authors(s,	a

function join_authors(s) {
	if (ref_entry["%NA"] == 0) {
		ref_entry["%A"] = parse_authors(s, 0)
		ref_entry["%F"] = parse_authors(s, 1)
	} else {
		ref_entry["%A"] = ref_entry["%A"] join_expr parse_authors(s, 0)
	}
	ref_entry["%NA"] += 1
}

/^%R\(/ {
	while(getline > 0) {
		if (/^%R\)/) {
			print_ref(ref_entry)
			next
		} else if (/^$/){
			print_ref(ref_entry)
			delete ref_entry
			continue
		} else if (/^[^%]/ || /^$/) {
			continue
		}

		tag = toupper($1)
		gsub(/^[^ ]+[ ]+/, "")

		if (tag == "%A") {
			join_authors($0)
			continue
		}

		if (tag == "%P")
			sub("-", "—")

		ref_entry[tag] = $0
	}
}

{
	print $0
}
