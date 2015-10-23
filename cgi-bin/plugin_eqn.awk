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
		print "<img style=\"margin-left:2em;\" alt=\"" html_escape(alt) "\" src=\"" image "\">"; next
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

		if (length(hint_sz) == 0)
			hint_sz = "0"

		img = sprintf("<img alt=\"%s\" src=\"%s\" " \
			      "style=\"vertical-align:%spx\">", html_escape(alt), image, hint_sz)

		sub(/\$\$[^\$]*\$\$/, img)
	}
}

function eqn_gen_image(s,	cmd, image)
{
	sub(/^[ \t]*/, "", s); sub(/[ \t]*$/, "", s)

	cmd = "./eqn_render.sh '" s "'"
	cmd | getline image;
	cmd | getline hint_sz;
	close(cmd);
	#printf("awk offset is %s image is '%s'\n", hint_sz, image)
	return image
}

