#!/usr/bin/python

from pygments import highlight
from pygments.lexers import get_lexer_by_name
from pygments.formatters import HtmlFormatter

from optparse import OptionParser

import sys

def gen_css():
    print HtmlFormatter().get_style_defs('.highlight')

def main():
    parser = OptionParser("%prog [opts] srcfile langname")
    parser.description = "html hilighter"
    parser.add_option('-c', '--cssgen', dest = "cssgen", action="store_true", default = False)

    (o, argv) = parser.parse_args()

    if o.cssgen:
        gen_css()
        return 0
    if len(argv) < 1:
        parser.print_usage()

    fpath = argv[0]
    lang = "c"
    if len(argv) > 1:
        lang = argv[1]

    code = open(fpath, "rb").read()
    lexer = get_lexer_by_name(lang, stripall=True)
    if not lexer:
        sys.stder.write("unknown lang name")
        return 1

    formatter = HtmlFormatter(linenos=True, cssclass="highlight")
    result = highlight(code, lexer, formatter)
    print result

    return 0

if __name__ == '__main__':
    sys.exit(main())
