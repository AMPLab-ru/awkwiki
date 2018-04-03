#!/usr/bin/awk -f
################################################################################
# awkiawki - wikiwiki clone written in (n|g|m)awk
# $Id: awki.cgi,v 1.45 2004/07/13 16:34:45 olt Exp $
################################################################################
# Copyright (c) 2002 Oliver Tonnhofer (olt@bogosoft.com)
# See the file `COPYING' for copyright notice.
################################################################################

@include "./hexcodes.awk"

BEGIN {
	# --- default options ---
	# --- use awki.conf to override default settings ---
	#
	localconf["wiki_name"] = "My"
	# datadir: Directory for raw pagedata (must be writeable for the script).
	localconf["datadir"] = "./data/"
	# parser: Parsing script.
	localconf["parser"] = "./parser.awk"
	# special_parser: Parser for special_* functions.
	localconf["special_parser"] = "./special_parser.awk"
	# default_page: Name of the default_page.
	localconf["default_page"] = "FrontPage"
	# show_changes: Number of changes listed by RecentChanges
	localconf["show_changes"] = 10
	# max_post: Bytes accept by POST requests (to avoid DOS).
	localconf["max_post"] = 2000000
	# write_protection: Regex for write protected files
	# e.g.: "*", "PageOne|PageTwo|^.*NonEditable"
	# HINT: to edit these protected pages, upload a .htaccess
	#       protected awki.cgi script with write_protection = ""
	localconf["write_protection"] = ""
	# css: HTTP URL for external CSS file.
	localconf["css"] = ""
	# always_convert_spaces: If true, convert runs of 8 spaces to tab automatical.
	localconf["always_convert_spaces"] = 0
	# date_cmd: Command for current date.
	localconf["date_cmd"] = "date '+%e %b. %G %R:%S %Z'"
	# rcs: If true, rcs is used for revisioning.
	localconf["rcs"] = 1
	# path: add path to PATH environment
	localconf["path"] = ""
	# sessions directory
	localconf["sessions"] = "./sessions/"
	# --- default options ---
	pagename_re = "[[:upper:]][[:lower:]]+[[:upper:]][[:alpha:]]*"

	scriptname = ENVIRON["SCRIPT_NAME"]

	if (localconf["path"])
		ENVIRON["PATH"] = localconf["path"] ":" ENVIRON["PATH"]

	#load external configfile
	load_config(scriptname)

	load_dict(dictionary, localconf["lang"])

	localconf["default_page"] = _("FrontPage")

	# PATH_INFO contains page name
	if (ENVIRON["PATH_INFO"])
		query["page"] = ENVIRON["PATH_INFO"]

	parse_cookies(cookies)

	if (ENVIRON["REQUEST_METHOD"] == "POST") {
		if (ENVIRON["CONTENT_TYPE"] == "application/x-www-form-urlencoded") {
			if (ENVIRON["CONTENT_LENGTH"] < localconf["max_post"])
				bytes = ENVIRON["CONTENT_LENGTH"]
			else
				bytes = localconf["max_post"]

			cmd = "dd ibs=1 count=" bytes " 2>/dev/null"
			cmd | getline query_str
			close (cmd)
		}
		if (ENVIRON["QUERY_STRING"])
			query_str = query_str "&" ENVIRON["QUERY_STRING"]
	} else {
		if (ENVIRON["QUERY_STRING"])
			query_str = ENVIRON["QUERY_STRING"]
	}

	n = split(query_str, querys, "&")
	for (i = 1; i <= n; i++) {
		split(querys[i], data, "=")
		query[data[1]] = data[2]
	}

	# (IMPORTANT for security!)
	query["page"] = clear_pagename(decode(query["page"]))
	query["revision"] = clear_revision(query["revision"])
	query["revision2"] = clear_revision(query["revision2"])
	query["string"] = clear_str(decode(query["string"]))

	if (!localconf["rcs"])
		query["revision"] = 0

	if (query["page"] == "")
		query["page"] = localconf["default_page"]

	query["filename"] = localconf["datadir"] query["page"]

	#check if page is editable
	special_pages = _("FullSearch") "|" _("PageList") "|" _("RecentChanges")

	if ("id" in cookies) {
		# *** !Important for Security! ***
		# id is a filename, check it is sane
		if (!match(cookies["id"], /[^a-zA-Z0-9]/)) {
			if (system("[ -f " localconf["sessions"] cookies["id"] " ]") == 0) {
				system("touch " localconf["sessions"] cookies["id"])
				auth_access = 1
			}
		} else {
			delete cookies["id"]
		}
	}

	if (query["page"] ~ "("special_pages")") {
		special_page = 1
	} else if (auth_access || !localconf["write_protection"] ||
		   query["page"] !~ "("localconf["write_protection"]")") {
		page_editable = 1
	}

	if (query["login"]) {
		result = check_login(query["username"], query["password"])
		query["action"] = "login"
	}

	if (query["register"]) {
		result = check_register(query["username"], query["password"], query["password0"])
		query["action"] = "register"
	}

	if (query["change_password"]) {
		result = check_change_password(query["password"], query["password0"])
		query["action"] = "change_password"
	}

	#set_cookie("count", cookies["count"] ? cookies["count"] + 1 : 0, "", "/")
	#set_cookie("user", "guest", "Tue, 15-Jan-2015 21:47:38 GMT", "/")
	header(query["page"])

	if (query["action"] == "edit" && page_editable)
		edit(query["page"], query["filename"], query["revision"])
	else if (query["action"] == "save" && query["text"] && page_editable)
		save(query["page"], query["text"], query["string"], query["filename"])
	else if (query["action"] == "login")
		result == "ok" ? welcome(query["username"]) : login(result)
	else if (query["action"] == "register")
		register(result)
	else if (query["action"] == "change_password")
		change_password(result)
	else if (query["action"] == "logout" && auth_access)
		farewell(cookies["id"])
	else if (query["page"] ~ _("PageList"))
		special_index(localconf["datadir"])
	else if (query["page"] ~ _("RecentChanges"))
		special_changes(localconf["datadir"])
	else if (query["page"] ~ _("FullSearch"))
		special_search(query["string"], localconf["datadir"])
	else if (query["page"] && query["action"] == "history")
		special_history(query["page"], query["filename"])
	else if (query["page"] && query["action"] == "diff" && query["revision"])
		special_diff(query["page"], query["filename"], query["revision"], query["revision2"])
	else
		parse(query["page"], query["filename"], query["revision"])

	footer(query["page"])

}

function set_cookie(name, value, expires, path, domain)
{
	delete cookies_header_header[name]
	cookies_header[name]["value"] = value

	if (expires)
		cookies_header[name]["expires"] = expires
	if (path)
		cookies_header[name]["path"] = path
	if (domain)
		cookies_header[name]["domain"] = domain
}

function parse_cookies(cookies,		arr, n, i, key, value)
{
	gsub(/[ ]*/, "", ENVIRON["HTTP_COOKIE"])

	if (length(ENVIRON["HTTP_COOKIE"]) == 0)
		return

	n = split(ENVIRON["HTTP_COOKIE"], arr, ";")
	for (i = 1; i <= n; i++) {
		if (match(arr[i], /=/)) {
			key = substr(arr[i], 1, RSTART-1)
			value = substr(arr[i], RSTART+RLENGTH)
			cookies[key] = value
		}
	}
}

function load_dict(dict, lang,		filename, saved_FS)
{
	filename = lang ".dict"
	saved_FS = FS
	FS = ":"

	while (getline <filename > 0)
		dict[$1] = $2

	close(filename)
	FS = saved_FS
}

function _(name)
{
	if (name in dictionary)
		return dictionary[name]

	return name
}

function header(page,	i, action, label)
{
	for (i in cookies_header)
		print "Set-Cookie: " i "=" cookies_header[i]["value"] \
			(cookies_header[i]["expires"] ? "; expires=" cookies_header[i]["expires"] : "") \
			(cookies_header[i]["path"] ? "; path=" cookies_header[i]["path"] : "") \
			(cookies_header[i]["domain"] ? "; domain=" cookies_header[i]["domain"] : "")

	print "Content-Type: text/html; charset=utf-8\n\n"

	print "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \
		\"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">"

	print "<html>\n<head>\n<title>" page "</title>"
	if (localconf["icon"])
		print "<link rel=\"shortcut icon\" href=\"" localconf["icon"] "\">"
	if (localconf["css"])
		print "<link rel=\"stylesheet\" href=\"" localconf["css"] "\">"
	if (query["action"] == "save" || (query["action"] == "login" && result == "ok") ||
		query["action"] == "logout" && auth_access)
		print "<meta http-equiv=\"refresh\" content=\"2,URL="scriptname"/"page"\">"
	print "</head>\n<body>\n<div id=\"container\">"
	print "\
<div id=\"header\">\n\
  <div id=\"header_inner\">\n\
    <div id=\"logo\" class=\"repeat\">\n\
      <a class=\"logo_link\" href=\""scriptname"/"localconf["default_page"]"\" title=\"" localconf["wiki_name"] " Wiki\"></a>\n\
    </div>\n\
    <div id=\"navigation\" class=\"repeat\">\n\
      <div id=\"utility_nav\">\n\
      </div>\n\
      <div id=\"primary_nav\">\n\
        <ul id=\"navibar\">\n\
          <li class=\"wikilink\"><a href=\""scriptname"/"localconf["default_page"]"\">"localconf["default_page"]"</a></li>"

	if (page_editable)
        	print "<li class=\"wikilink\"><a href=\""scriptname"?action=edit&amp;page="page"\">" _("Edit") "</a></li>"
	if (localconf["rcs"] && !special_page)
        	print "<li class=\"wikilink\"><a href=\""scriptname"/"page"?action=history\">" _("PageHistory") "</a></li>"

	print "\
          <li class=\"wikilink\"><a href=\""scriptname"/" _("RecentChanges") "\">" _("RecentChanges") "</a></li>\n\
        <li class=\"wikilink\"><a href=\"" scriptname "/" _("PageList") "\">" _("PageList") "</a>\n\
        </ul>\n\
      </div>\n\
    </div>\n\
  </div>\n\
</div>\n\
<div id=\"wrapper\">\n\
  <div id=\"wrapper_inner\">\n\
    <div id=\"sidebar\" class=\"repeat\">\n\
      <h2>" _("Search Wiki") "</h2>\n\
      <form id=\"searchform\" method=\"GET\" accept-charset=\"UTF-8\" action=\""scriptname"/" _("FullSearch") "\">\n\
        <div>\n\
          <input id=\"searchinput\" type=\"text\" name=\"string\">\n\
          <input id=\"fullsearch\" type=\"submit\" value=\"" _("Search") "\">\n\
        </div>\n\
      </form>\n\
      <br/>\n\
      <h2>" _("User actions") "</h2>\n\
      <ul id=\"username\">"
	if (!auth_access)
		print "\
        <li><a href=\""scriptname"?action=login \" id=\"login\" rel=\"nofollow\">" _("Login") "</a></li>\n\
        <li><a href=\""scriptname"?action=register \" id=\"login\" rel=\"nofollow\">" _("Register") "</a></li>"
	else
		print "\
        <li><a href=\""scriptname"?action=change_password \" id=\"login\" rel=\"nofollow\">" _("Change password") "</a></li>\n\
        <li><a href=\""scriptname"?action=logout \" id=\"login\" rel=\"nofollow\">" _("Logout") "</a></li>"
	print "\
      </ul>\n\
    </div>\n\
    <div id=\"content\">"
}

# print footer
function footer(page,	cmd, year)
{
	cmd = "date +%Y"
	cmd | getline year
	close(cmd)
	print "</div></div></div>"
	print "<div id=\"footer\"><div id=\"footer_inner\">" localconf["wiki_name"] " " year "</div></div>"
	print "</div>\n</body>\n</html>"
}

# send page to parser script
function parse(name, filename, revision,	parser_cmd)
{
	parser_cmd = localconf["parser"] " -v datadir='" localconf["datadir"] "' -v pagename='" name "'" 
	if (system("[ -f "filename" ]") == 0 ) {
		if (revision) {
			print "<em>" _("Displaying old version") " ("revision") " _("of") " <a href=\""scriptname"/" name "\">"name"</a>.</em>"
			system("co -q -p'"revision"' " filename " | " parser_cmd)
		} else
			system("cat " filename " | " parser_cmd)
	}
}

function special_diff(page, filename, revision, revision2,   revisions)
{
	if (system("[ -f "filename" ]") == 0) {
		print "<em>" _("Displaying diff between") " " revision
		if (revision2)
			print " " _("and") " " revision2
		else
			print " " _("and current version")
		print " " _("of") " <a href=\""scriptname"/"page "\">"page"</a>.</em>"
		if (revision2)
			revisions = "-r" revision " -r" revision2
		else
			revisions = "-r" revision
		system("rcsdiff "revisions" -u "filename" | " localconf["special_parser"] " -v special_diff='"page"'")
	}
}	

function welcome(username)
{
	print "<span>" _("You are logged in as") " <b>" username "</b></span>"
}

function farewell(cookie,	file, username)
{
	file = localconf["sessions"] cookie
	getline username <file
	close(file)
	system("rm -f " localconf["sessions"] cookie)

	print "<span><b>" username  "</b>, "  _("you are logged out") "</span>"
}

function login(msg)
{
	print "\
<form action=\""scriptname"\" method=\"POST\" accept-charset=\"UTF-8\">\n\
  <div id=\"login\">\n\
    <table bordr=\"0\">\n\
      <tr>\n\
        <td>" _("Username") "</td>\n\
        <td><input type=\"text\" name=\"username\" size=\"32\"></td>\n\
      </tr>\n\
      <tr>\n\
        <td>" _("Password") "</td>\n\
        <td><input type=\"password\" name=\"password\" size=\"32\"></td>\n\
      </tr>\n\
      <tr>\n\
        <td></td>\n\
        <td><input type=\"submit\" name=\"login\" value=\"" _("Login") "\"></td>\n\
      </tr>\n\
    </table>\n\
  </div>\n\
</form>"
	if (msg)
		print msg
}

function check_login(username, password,	cmd, id)
{
	if (!username || !password)
		return _("Username or password is empty") "."

	if (!match(username, /^[a-zA-Z0-9_-]+$/) || !match(password, /^[^'":]+$/))
		return _("Wrong characters at username or password")

	if (system(localconf["login_cmd"] " " username " " password))
		return _("Username or password is wrong") "."

	cmd = "basename $(mktemp " localconf["sessions"] "XXXXXXXXXXXXX)"
	cmd | getline id
	close(cmd)

	set_cookie("id", id, "", "/")
	cookies["id"] = id
	print username > localconf["sessions"] id

	return "ok"
}

function register(msg)
{
	print "\
<form action=\""scriptname"\" method=\"POST\" accept-charset=\"UTF-8\">\n\
  <div id=\"register\">\n\
    <table bordr=\"0\">\n\
      <tr>\n\
        <td>" _("Username") "</td>\n\
        <td><input type=\"text\" name=\"username\" size=\"32\"></td>\n\
      </tr>\n\
      <tr>\n\
        <td>" _("Password") "</td>\n\
        <td><input type=\"password\" name=\"password\" size=\"32\"></td>\n\
      </tr>\n\
      <tr>\n\
        <td>" _("Repeat password") "</td>\n\
        <td><input type=\"password\" name=\"password0\" size=\"32\"></td>\n\
      </tr>\n\
      <tr>\n\
        <td></td>\n\
        <td><input type=\"submit\" name=\"register\" value=\"" _("Register") "\"></td>\n\
      </tr>\n\
    </table>\n\
  </div>\n\
</form>"
	if (msg)
		print msg
}

function change_password(msg)
{
	print "\
<form action=\""scriptname"\" method=\"POST\" accept-charset=\"UTF-8\">\n\
  <div id=\"change_password\">\n\
    <table bordr=\"0\">\n\
      <tr>\n\
        <td>" _("Password") "</td>\n\
        <td><input type=\"password\" name=\"password\" size=\"32\"></td>\n\
      </tr>\n\
      <tr>\n\
        <td>" _("Repeat password") "</td>\n\
        <td><input type=\"password\" name=\"password0\" size=\"32\"></td>\n\
      </tr>\n\
      <tr>\n\
        <td></td>\n\
        <td><input type=\"submit\" name=\"change_password\" value=\"" _("Change password") "\"></td>\n\
      </tr>\n\
    </table>\n\
  </div>\n\
</form>"
	if (msg)
		print msg
}

function check_register(username, password, password0,	cmd, id, hash)
{
	if (!username || !password)
		return _("Username or password is empty") "."

	if (!match(username, /^[a-zA-Z0-9_-]+$/) || !match(password, /^[^'":]+$/))
		return _("Wrong characters at username or password")

	if (system("grep '" username "' " localconf["passwd_path"]) == 0)
		return _("This user already exists") "."

	if (password != password0)
		return _("Username or password is wrong") "."

	cmd = "echo -n '" password "' | sha1sum | cut -d ' ' -f 1"
	cmd | getline hash
	close(cmd)

	system("echo " username ":" hash " >> " localconf["passwd_path"])

	cmd = "basename $(mktemp " localconf["sessions"] "XXXXXXXXXXXXX)"
	cmd | getline id
	close(cmd)

	set_cookie("id", id, "", "/")
	cookies["id"] = id
	print username > localconf["sessions"] id

	return "ok"
}

function check_change_password(password, password0,	cmd, username, hash, file, tmp)
{
	if (!password)
		return _("Username or password is empty") "."

	if (password != password0)
		return _("Username or password is wrong") "."

	if (!match(password, /^[^'":]+$/))
		return _("Wrong characters at username or password")

	cmd = "echo -n " password " | sha1sum | cut -d ' ' -f 1"
	cmd | getline hash
	close(cmd)

	cmd = "cat " localconf["sessions"] cookies["id"]
	cmd | getline username
	close(cmd)

	file = ""
	cmd = "grep -v '^" username "' " localconf["passwd_path"]

	while (cmd | getline tmp > 0)
		file = file "\n" tmp

	close(cmd)

	file = "\n" username ":" hash "\n"

	print file > localconf["passwd_path"]

	return "ok"
}

# print header
# print edit form
function edit(page, filename, revision,   cmd)
{
	if (revision)
		print "<p><small><em>" _("If you save previous versions, you'll overwrite the current page") ".</em></small>"
	print "<form action=\""scriptname"?action=save&amp;page="page"\" method=\"POST\" accept-charset=\"UTF-8\">"
	print "<textarea name=\"text\" rows=35 cols=100>"
	# insert current page into textarea
	if (revision) {
		cmd = "co -q -p'"revision"' " filename
		while (cmd | getline > 0)
			print
		close(cmd)
	} else {
		while (getline <filename > 0)
			print
		close(filename)
	}
	print "</textarea><br />"
	print "<input type=\"submit\" value=\"" _("Save") "\">"
	if (localconf["rcs"])
		print _("Comment") ": <input type=\"text\" name=\"string\" maxlength=80 size=50>"
	if (!localconf["always_convert_spaces"])
		print "<br>Convert runs of 8 spaces to Tab <input type=\"checkbox\" name=\"convertspaces\">"
	print "</form>"
}

# save page
function save(page, text, comment, filename,   dtext, date, file, username)
{
	dtext = decode(text)
	if (localconf["always_convert_spaces"] || query["convertspaces"] == "on")
		gsub(/        /, "\t", dtext)
	print dtext > filename

	file = localconf["sessions"] cookies["id"]
	getline username <file
	close(file)
	if (username == "")
		username = "anonymous"


	if (localconf["rcs"]) {
		localconf["date_cmd"] | getline date
		system("ci -q -t-"page" -w"username" -l -m'"ENVIRON["REMOTE_ADDR"] ";;" date ";;"comment"' " filename)
		close(localconf["date_cmd"])
	}
	print "<a href=\""scriptname"/"page"\">"page"</a> " _("is saved")
}

# list all pages
function special_index(datadir)
{
	system("ls -1 " datadir " | " localconf["special_parser"] " -v special_index=yes")
	
}

# list pages with last modified time (sorted by date)
function special_changes(datadir,   date)
{
	localconf["date_cmd"] | getline date
	print "<p>" _("Current date") ":", date "<p>"
	system("ls -tlL "datadir" | " localconf["special_parser"] " -v special_changes=" localconf["show_changes"])
	close(localconf["date_cmd"])
}

function special_search(name, datadir)
{
	system("grep -il '"name"' "datadir"* | " localconf["special_parser"] " -v special_search=yes")
}

function special_history(name, filename)
{
	print "<p>" _("Last changes on") " <a href=\""scriptname"/" name "\">"name"</a><p>"
	system("rlog " filename " | " localconf["special_parser"] " -v special_history="name)

	print "<p>" _("Show diff between") ":"
	print "<form action=\""scriptname"/\" method=\"GET\">"
	print "<input type=\"hidden\" name=\"page\" value=\""name"\">"
	print "<input type=\"hidden\" name=\"diff\" value=\"true\">"
	print "<input type=\"text\" name=\"revision\" size=5>"
	print "<input type=\"text\" name=\"revision2\" size=5>"
	print "<input type=\"submit\" value=\"diff\">"
	print "</form></p>"
}

# remove '"` characters from string
# *** !Important for Security! ***
function clear_str(str)
{
	gsub(/['`"]/, "", str)
	if (length(str) > 80) 
		return substr(str, 1, 80)
	else
		return str
}

# retrun the pagename
# *** !Important for Security! ***
function clear_pagename(str, r)
{
	if (match(str, pagename_re)) {
		return substr(str, RSTART, RLENGTH)
	} else
		return ""
}

# return revision numbers
# *** !Important for Security! ***
function clear_revision(str)
{
	if (match(str, /[1-9]\.[0-9]+/))
		return substr(str, RSTART, RLENGTH)
	else
		return ""
}

# decode urlencoded string
function decode(text,   hex, i, hextab, decoded, len, c, c1, c2, code)
{
	split("0 1 2 3 4 5 6 7 8 9 a b c d e f", hex, " ")
	for (i = 0; i < 16; i++)
		hextab[hex[i+1]] = i

	# urldecode function from Heiner Steven
	# http://www.shelldorado.com/scripts/cmds/urldecode

	# decode %xx to ASCII char 
	decoded = ""
	i = 1
	len = length(text)
	
	while (i <= len) {
		c = substr (text, i, 1)
		if (c == "%") {
			if (i + 2 <= len) {
				c1 = tolower(substr(text, i + 1, 1))
				c2 = tolower(substr(text, i + 2, 1))
				if (hextab [c1] != "" || hextab [c2] != "") {
					code = 0 + hextab[c1] * 16 + hextab[c2] + 0
					c = hexval[code]
					i = i + 2
				}
			}
		} else if ( c == "+" ) {
			# special handling: "+" means " "
			c = " "
		}

		decoded = decoded c
		++i
	}

	# change linebreaks to \n
	gsub(/\r\n/, "\n", decoded)
	
	# remove last linebreak
	sub(/[\n\r]*$/,"", decoded)

	return decoded
}

# load configfile
function load_config(script,   configfile, key, value)
{
	configfile = script
	#remove trailing / ('/awki/awki.cgi/' -> '/awki/awki.cgi')
	sub(/\/$/, "", configfile)
	#remove path ('/awki/awki.cgi' -> 'awki.cgi')
	sub(/^.*\//, "", configfile)
	#remove suffix ('awki.cgi' -> 'awki')
	sub(/\.[^.]*$/,"", configfile)
	# append .conf suffix
	configfile = configfile ".conf"
	
	# read configfile
	while (getline <configfile > 0) {
		# ignore comments
		if ($0 ~ /^#/) continue
		
		if (match($0,/[ \t]*=[ \t]*/)) {
			key = substr($0, 1, RSTART-1)
			sub(/^[ \t]*/, "", key)
			value = substr($0, RSTART+RLENGTH)
			sub(/[ \t]*$/, "", value)
			if (sub(/^"/, "", value))
				sub(/"$/, "", value) 
			# set localconf variables
			localconf[key] = value
		}
	}
	close(configfile)
}	

