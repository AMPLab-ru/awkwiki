#TODO: escape paths
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

