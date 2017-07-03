#!/usr/bin/env python

# (c) Shahar Valiano, 2017

from __future__ import print_function
import os
import re
import sys


# -----------------------------------------------------------------------------
# Utility functions
# -----------------------------------------------------------------------------


def strip_path(full_path):
    return os.path.basename(full_path)


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


def mkdir_p(dirname):
    if not os.path.isdir(dirname):
        try:
            os.mkdir(dirname)
        except OSError:
            return False
    return True


def regexp_is_valid(regexp):
    try:
        re.compile(regexp)
        is_valid = True
    except re.error:
        is_valid = False
    return is_valid


def check_file(infile):
    if not os.path.isfile(infile):
        eprint("ERROR: input file %s doesn't exist." % infile)
        exit(1)


def create_dir(dir):
    if not mkdir_p(dir):
        eprint("ERROR: couldn't create folder %s." % dir)
        exit(1)


def check_regexp(regexp):
    if not regexp_is_valid(regexp):
        eprint("ERROR: \"%s\" is not a valid Python regular expression." % regexp)
        exit(1)


def cut_text(infile, regexp):
    # Sanity checks
    if not os.path.isfile(infile) or not regexp_is_valid(regexp):
        return False
    compiled_regexp = re.compile(regexp)
    with open(infile) as inF:
        for line in inF:
            print(line.strip())
            if compiled_regexp.search(line):
                break


def split_text(infile, resdir, regexp):

    def get_currfile_name(outfile_basename, filecount, outfile_ext):
        currfile = "%s.%s.%s" % (outfile_basename, str(filecount).zfill(3), outfile_ext)
        return currfile

    # Sanity checks
    if not os.path.isfile(infile) or not os.path.isdir(resdir):
        return False
    if not regexp_is_valid(regexp):
        return False

    compiled_regexp = re.compile(regexp)
    outfile_basename = "%s/out" % resdir
    outfile_ext = "txt"
    filecount = 0
    start_index = 1
    first = True
    currfile = get_currfile_name(outfile_basename, filecount + start_index, outfile_ext)

    outF = open(currfile, 'w')
    outF.close()

    print("\nProcessing...\n")

    with open(infile) as inF:
        for line in inF:
            if compiled_regexp.search(line):
                filecount = filecount + 1
                if first:
                    outF = open(currfile, 'w')
                    first = False
                else:
                    outF.close();
                    outF = open(currfile, 'w')
                print("Created file %s..." % currfile)
                currfile = get_currfile_name(outfile_basename, filecount + start_index, outfile_ext)
            if not first:
                outF.write(line)

    outF.close()
    if filecount == 0:
        os.remove(currfile)
        print("NOTE: Regular expression \"%s\" was not matched in input file." % regexp)
    print("NOTE: Input file split into %d files." % filecount)


# EOF
