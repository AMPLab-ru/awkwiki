#!/usr/bin/awk -f

BEGIN {
	join_expr = ", "
	fmt_authors = "\t1 %FA %T / %A"
	fmt_issuer = "— %C %I %D"
	fmt_url = ".— %U"
}

function fmt_string(a, s,	nsubs) {
	nsubs = 0
	for (i in a) {
		nsubs += sub(i, a[i], s)
	}

	if (nsubs == 0)
		return ""

	return s
}

function print_ref(a,	i, str) {

	out = fmt_string(a, fmt_authors)
	out = out fmt_string(a, fmt_issuer)
	out = out fmt_string(a, fmt_url)

	#Cleanup fmt string
	gsub(/ %[A-Z]+/, "", out)

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
