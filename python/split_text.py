#!/usr/bin/env python

# (c) Shahar Valiano, 2017

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
        print "Usage: %s <input file> <dest. folder> <regexp>\n" % cls._scriptName
        print "- The script splits <input file> into multiple smaller files."
        print "  A new file is created whenever input line is matched to regexp."
        print "- If regexp is not matched, no files are written."
        exit(1)

    @classmethod
    def parse_args(cls):
        if len(sys.argv) != 4:
            cls.usage()
        infile = sys.argv[1]
        resdir = sys.argv[2]
        regexp = sys.argv[3]

        utils.check_file(infile)
        utils.create_dir(resdir)
        utils.check_regexp(regexp)

        cls.print_script_params(infile, resdir, regexp)
        return (infile, resdir, regexp)

    @classmethod
    def print_script_params(cls, infile, resdir, regexp):
        print "Script parameters:"
        print "* Input file:   %s" % infile
        print "* Results dir:  %s" % resdir
        print "* Split regexp: %s" % regexp

# -----------------------------------------------------------------------------
# main
# -----------------------------------------------------------------------------

def main():
    (infile, resdir, regexp) = Helper.parse_args()
    utils.split_text(infile, resdir, regexp)

if __name__ == '__main__':
    main()
