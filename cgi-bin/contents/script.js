var cont = document.getElementById("contents-content");
var list = document.getElementsByClassName("header");

var prev = 1;
var lvl = 0;
var buf = "";

var i;

for (i = 0; i < list.length; i++) {
	var cur;

	switch(list[i].tagName) {
	case "H2":
		cur = 2;
		break;
	case "H3":
		cur = 3;
		break;
	case "H4":
		cur = 4;
		break;
	}

	if (cur > prev) {
		buf += '<ol>\n';
		lvl++;
	} else if (cur < prev) {
		buf += '</ol>\n';
		lvl--;
	}
	prev = cur;

	buf += '\t<li><a href="#'
	+ list[i].id + '">'
	+ list[i].innerHTML + '</a></li>\n';
}

for (i = 0; i < lvl; i++) {
	buf += '</ol>\n';
}
console.log(buf);
cont.innerHTML += buf;

