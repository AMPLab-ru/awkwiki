/^%EQ$/, /^%EN$/ {
	if (/^%EQ$/) {
		eqn = ""; next
	}

	if (/^%EN$/) {
		alt = eqn;

		eqn = unescape(eqn)
		image = eqn_gen_image(eqn)
		if (blankline == 1) {
			print "<p>"; blankline = 0
		}

		if (align_property == "")
			align_property = "0"

		print sprintf("<img alt=\"%s\" src=\"%s\" " \
			      "style=\"margin-left:2em; vertical-align:%spx\">",
			      html_escape(alt), image, align_property)
	}

	eqn = eqn ? eqn "\n" $0 : $0; next
}

# embedded eqn
/\$\$[^\$]*\$\$/ {
	while (match($0, /\$\$[^\$]*\$\$/)) {
		eqn = substr($0, RSTART, RLENGTH)
		gsub(/\$\$/, "", eqn)
		# the last gsub() is very important, alt is used in sub() below
		alt = eqn;
		eqn = unescape(eqn)
		image = eqn_gen_image(eqn)

		if (align_property == "")
			align_property = "0"

		img = sprintf("<img alt=\"%s\" src=\"%s\" " \
			      "style=\"vertical-align:%spx\">", html_escape(alt),
			      image, align_property)

		sub(/\$\$[^\$]*\$\$/, img)
	}
}

function eqn_gen_image(s,	cmd, image)
{
	sub(/^[ \t]*/, "", s); sub(/[ \t]*$/, "", s)

	cmd = "./eqn_render.sh '" s "'"
	cmd | getline image;
	cmd | getline align_property;
	close(cmd);
	#printf("awk offset is %s image is '%s'\n", align_property, image)
	return image
}

