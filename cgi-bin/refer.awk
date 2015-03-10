#!/usr/bin/awk -f

BEGIN {
	join_expr = ", "

	fmt_authors = "\t1 %F %T / %A"
	fmt_q_author = "\t1 %T / %Q"
	fmt_book = "// %B"
	fmt_issuer = " — %C %I %D"
#fmt_serial = " — (%B, %V)"
	fmt_phys_info = " — %P"
	fmt_url = ". — %U"
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

function print_ref(a,	i, str) {
	if (arrlen(a) == 0) {
		print ""
		return
	}

	if (a["%Q"] != "")
		out = fmt_string(a, fmt_q_author)
	else
		out = fmt_string(a, fmt_authors)

	out = add_ending_dot(out \
			     fmt_string(a, fmt_book)) \
	    add_ending_dot(fmt_string(a, fmt_issuer)) \
	    add_ending_dot(fmt_string(a, fmt_serial)) \
	    add_ending_dot(fmt_string(a, fmt_phys_info)) \
	    add_ending_dot(fmt_string(a, fmt_url))

	#Cleanup fmt string
	gsub(/%[A-Z]+/, "", out)
	
	printf("%s\n", out)
}

function parse_first_author(s,	a, initials, surname) {
	split(s, a, " ")
	for (i = 0; i < length(a); i++) {
		if (length(a[i]) > 2) {
			surname = a[i]
			continue;
		}

		initials = initials " " a[i]
	}

	return surname "," initials
}

function join_authors(s) {
	if (ref_entry["%NA"] == 0) {
		ref_entry["%A"] = s
		ref_entry["%F"] = parse_first_author(s)
	} else {
		ref_entry["%A"] = ref_entry["%A"] join_expr s
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
			continue;
		}

		tag = toupper($1)
		gsub(/^[^ ]+[ ]+/, "")

		if (tag == "%A") {
			join_authors($0)
		} else {
			ref_entry[tag] = $0
		}
	}
}

{
	print $0
}
