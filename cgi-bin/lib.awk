#TODO: escape paths

function arrlen(a,	i, x) {
	for (x in a)
		i++

	return i
}

function mktemp(dstdir,	dirname)
{
	cmd = "mktemp " dstdir "XXXXXXXXX"
	cmd | getline dirname
	close(cmd)

	return dirname
}

function rmfile(fpath,		unused)
{
	cmd = "rm -f '" fpath "'"
	cmd | getline unused
	close(cmd)
}

function strip_spaces(s)
{
	gsub(/^[ \t]+/, "", s)
	gsub(/[ \t]+$/, "", s)
	gsub(/[ \t]+/, " ", s)
	return s
}

function rm_quotes(s)
{
	gsub(/''''''/, "", s)
	gsub(/'''/, "", s)
	gsub(/''/, "", s)
	gsub(/``/, "", s)
	return s
}

