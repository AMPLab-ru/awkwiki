#!/usr/bin/awk -f

#Ссылка на гост, под который делаетя оформление
#https://ru.wikisource.org/wiki/%D0%93%D0%9E%D0%A1%D0%A2_7.1%E2%80%942003

#%F - internal tag, first author
#Описание формата записей:
# % - символ после которого идёт имя тега
# [] - символы, которыми выделяются необязательные блоки
# Если [] разделены символом | это означает что будет подставлен *первый* опциональный блок, который смог сматчится
# \обозначает экранированный символ, например можно экранировать символы []
BEGIN {
	refer_entry_fmt = "\t1 %A %T.[: %I][, %D][-- URL: %U]"

	header_section = "%F [%T][ : %O][ / %A]"
	issuer_section = "[. — [%C [ : %I]]|[ %I][ - %D]]"

	physical_info_section = "[. — %P]"
	notes_section = "[. — %U]"

	reference = sprintf("%s%s%s%s", header_section,
	    issuer_section,
	    physical_info_section,
	    notes_section)

	refer_entry_fmt = sprintf("\t1 %s",
				reference)
	
	join_authors = ", "
	inside_refer = 0
}

/^%R\(/ {
	inside_refer = 1
	next
}

/^%R\)/ {
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

#Naive author sanitize function
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

function concat_authors(s) {
	if (ref_entry["%NA"] == 0) {
		ref_entry["%A"] = s
		ref_entry["%F"] = parse_first_author(s)
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

function cond_skip_all(	indent) {
	indent = 1

	#skip all
	while (get_next_tok() != "EOF") {
		if (TOK["type"] != "expr")
			continue
		if (TOK["value"] == "[")
			indent++
		if (TOK["value"] == "]")
			indent--
		if (indent < 1)
			break
	}
}

#NOTE: on error try to parse till ']'
#REWRITE Conditional operator
function parse_cond(entry,	r, tag, tmp, cond_flg) {

	get_next_tok()

	while (1) {

		if (TOK["type"] == "EOF") {

			break

		} else if (TOK["type"] == "expr" &&
			   TOK["value"] == "|" &&
			   cond_flg == 1) {

			do {
				get_next_tok()
				if (TOK["type"] != "expr" ||
				    TOK["value"] != "[")
					break

			    	if (length(tmp) != 0) {
					cond_skip_all()
					continue
				}

				tmp = parse_cond(entry)
				r = r tmp

			} while (get_next_tok() == "expr" &&
			    	 TOK["value"] == "|")

			continue 

		} else if (TOK["type"] == "tag") {
			tag = TOK["value"]
			tmp = format_tag(tag, entry[tag])

			if (tmp == "")
				break;

			r = r tmp

		} else if (TOK["type"] == "expr" &&
			   TOK["value"] == "]") {

			   return r
			   
		} else if (TOK["type"] == "expr" &&
			   TOK["value"] == "[") {
			#U
			tmp = parse_cond(entry)
			r = r tmp
			cond_flg = 1
			get_next_tok()

			continue

		} else { #string or unknown
			r = r TOK["value"]
		} 

		cond_flg = 0
		get_next_tok()
	}

	cond_skip_all()


	return ""
}

#STR some global variables for pasing
#IDX
function get_string(	start, res, a) {

	start = IDX
	for (IDX; IDX < length(STR); IDX++) {
		ch = substr(STR, IDX, 1)
		if (ch == "\\") {
			IDX++
			continue
		} else if (ch == "%" 	\
		    || ch == "["	\
		    || ch == "]"	\
		    || ch == "|") {
		    	break
		}
		
	}

	TOK["type"] = "string"
	TOK["value"] = substr(STR, start, IDX - start)
	#printf("get_string '%s' start %d IDX = %d\n", TOK["value"], start, IDX)
}

#fills global array TOK
function get_next_tok(	start, a) {

	start = IDX

	ch = substr(STR, IDX, 1)
	
	#printf("ch = '%s'\n", ch)
	if (IDX > length(STR) || ch == "") {
		TOK["type"] = "EOF"
		return
	}

	switch (ch) {
	case "%":
		TOK["type"] = "tag"
		TOK["value"] = substr(STR, IDX, 2)

		IDX += 2

		break
	case "[":
	case "|":
	case "]":
		IDX++
		TOK["type"] = "expr"
		TOK["value"] = ch
		
		break
	default:
		get_string()
		break
	}

	return TOK["type"]
}

function format_ref(entry,	r, tag, tmp) {
	IDX = 1
	STR = refer_entry_fmt

	#print STR

	while (1) {
		get_next_tok()

		if (TOK["type"] == "EOF") {

			break

		} else if (TOK["type"] == "tag") {

			tag = TOK["value"]
			tmp = format_tag(tag, entry[tag])
			r = r tmp

		} else if (TOK["type"] == "expr" &&
			   TOK["value"] == "[") {

			r = r parse_cond(entry)

		} else { #string or unknown
			r = r TOK["value"]
		} 

		#printf("format_ref = %s %s\n", TOK["type"], TOK["value"])
	}

	return r
}

