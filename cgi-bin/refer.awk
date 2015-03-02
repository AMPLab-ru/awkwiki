#!/usr/bin/awk -f

BEGIN {
	refer_entry_fmt = "\t1 %A %T.[: %I][, %D][: %H]"
	join_authors = ", "
}

/\s*%REF%\s*$/ {
	inside_refer = 1
	next
}

/^\s*%REF\s+END%\s*$/ {
	inside_refer = 0
	entry_finish()
	next
}

inside_refer == 0 {
	print $0
}

inside_refer == 1 {
	if (match($0, /^%[a-zA-Z]/)) {
		inside_entry = 1

		tag = toupper(substr($0, 1, 2))
		if (tag == "%A") {
			concat_authors(substr($0, 4))
			next
		}
		ref_entry[tag] = substr($0, 4)

	} else if (match($0, /^\s*$/)) {
		entry_finish()
	}
}

function concat_authors(s) {
	if (ref_entry["%NA"] == 0) {
		ref_entry["%A"] = s
	} else {
		ref_entry["%A"] = ref_entry["%A"] join_authors s
	}
	ref_entry["%NA"] += 1
}

function entry_finish() {
	if (inside_entry)
		print format_ref(ref_entry)

	delete ref_entry
	inside_entry = 0
}

#We can use it for special formatting
function format_tag(tag, value) {
	if (tags_fmt[tag] == "" || value == "")
		return value

	return sprintf(tags_fmt[tag], value)
}

#NOTE: on error try to parse till ']' and set RLENGTH
function parse_cond(entry, fmt,		r, ch, tag, tmp) {
	RLENGTH = 0

	if (substr(fmt, 1, 1) != "[")
		return ""

	for (i = 2; i <= length(fmt); i++) {
		ch = substr(fmt, i, 1)
		if (ch == "%") {
			tag = substr(fmt, i, 2)
			tmp = format_tag(tag, entry[tag])
			if (tmp == "")
				break
			r = r tmp
			i++
		} else if (ch == "[") {
			tmp = parse_cond(entry, substr(fmt, i + 1))
			if (tmp == "")
				break
			i += RLENGTH
			r = r tmp
		} else if (ch == "]") {
			RLENGTH = i
			return r
		} else {
			r = r ch
		}
	}

	#On error try to find ']' pair.
	indent = 1
	for (i; i <= length(fmt); i++) {
		ch = substr(fmt, i, 1)
		if (ch == "[")
			indent++
		else if (ch == "]")
			indent--

		if (indent < 1) {
			RLENGTH = i
			return ""
		}
	}

	return ""
}

function format_ref(entry,	ch, x, fmt, r, idx, i) {
	r = ""
	fmt = refer_entry_fmt

	for (i = 1; i <= length(fmt); i++) {
		ch = substr(fmt, i, 1)
		if (ch == "%") {
			tag = substr(fmt, i, 2)
			tmp = format_tag(tag, entry[tag])
			r = r tmp
			i++
		} else if (ch == "[") {
			tmp = parse_cond(entry, substr(fmt, i))
			#printf("parse_cond = '%s' len = %d\n", tmp, RLENGTH);
			if (tmp == "") {
				i += RLENGTH - 1
				continue
			}
			r = r tmp
			i += RLENGTH - 1
		} else {
			r = r ch
		}
	}

	return r
}

