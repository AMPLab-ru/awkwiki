BEGIN {
	syntax["\\{\\|"] = "tbl_main"
}

function tbl_main()
{
	sub(/^\{\|[\ ]*/, "")
	sub(/ *$/, "")

	if (/^left$/ || /^center$/ || /^right$/)
		print "<div align=\"" $0 "\">"
	else
		print "<div>"

	print "<table class=\"table\">"
	wiki_print_tbl()
	print "</table>\n</div>"

}

function wiki_print_tbl(	i, j, attr, cattr, cells, colspan, rowspan)
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

				cells[i] = wiki_format_line(cells[i])
				print "<td " attr ">"  cells[i] "</td>"
			}
		}
	}

	print "</tr>"
}

