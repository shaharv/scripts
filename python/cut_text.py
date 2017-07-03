#!/usr/bin/env python

import os
import re
import sys
import utils

# -----------------------------------------------------------------------------
# Helper class
# -----------------------------------------------------------------------------

class Helper:

    _scriptName = utils.strip_path(sys.argv[0])

    @classmethod
    def script_name(cls):
        return cls._scriptName

    @classmethod
    def usage(cls):
        print "Usage: %s <input file> <regexp>\n" % cls._scriptName
        print "- The script reads <input file> and cuts all text starting"
        print "  the first list matching <regexp>. Result is printed"
        print "  to stdout."
        exit(1)

    @classmethod
    def parse_args(cls):
        if len(sys.argv) != 3:
            cls.usage()
        infile = sys.argv[1]
        regexp = sys.argv[2]

        utils.check_file(infile)
        utils.check_regexp(regexp)

        cls.print_script_params(infile, regexp)
        return (infile, regexp)

    @classmethod
    def print_script_params(cls, infile, regexp):
        print "Script parameters:"
        print "* Input text file:     %s" % infile
        print "* Regexp to cut after: %s" % regexp

# -----------------------------------------------------------------------------
# main
# -----------------------------------------------------------------------------

def main():
    (infile, regexp) = Helper.parse_args()
    utils.cut_text(infile, regexp)

if __name__ == '__main__':
    main()