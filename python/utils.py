#!/usr/bin/env python

# (c) Shahar Valiano, 2018

from __future__ import print_function

import os
import platform
import re
import subprocess
import sys
from subprocess import PIPE, STDOUT

import ConfigParser

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
        eprint(f"ERROR: input file {infile} doesn't exist.")
        sys.exit(1)


def create_dir(dirpath):
    if not mkdir_p(dirpath):
        eprint(f"ERROR: couldn't create folder {dirpath}.")
        sys.exit(1)


def check_regexp(regexp):
    if not regexp_is_valid(regexp):
        eprint(f'ERROR: "{regexp}" is not a valid Python regular expression.')
        sys.exit(1)


def cut_text(infile, regexp):
    # Sanity checks
    if not os.path.isfile(infile) or not regexp_is_valid(regexp):
        return False
    compiled_regexp = re.compile(regexp)
    with open(infile, encoding='utf-8') as inF:
        for line in inF:
            print(line.strip())
            if compiled_regexp.search(line):
                break
    return True


def split_text(infile, resdir, regexp):

    def get_currfile_name(outfile_basename, filecount, outfile_ext):
        currfile = f"{outfile_basename}.{str(filecount).zfill(3)}.{outfile_ext}"
        return currfile

    # Sanity checks
    if not os.path.isfile(infile) or not os.path.isdir(resdir):
        return False
    if not regexp_is_valid(regexp):
        return False

    compiled_regexp = re.compile(regexp)
    outfile_basename = f"{resdir}/out"
    outfile_ext = "txt"
    filecount = 0
    start_index = 1
    first = True
    currfile = get_currfile_name(outfile_basename, filecount + start_index, outfile_ext)

    with open(currfile, 'w', encoding='utf-8') as outF:
        outF.write('')  # Create empty file

    print("\nProcessing...\n")

    with open(infile, encoding='utf-8') as inF:
        outF = None
        for line in inF:
            if compiled_regexp.search(line):
                filecount = filecount + 1
                if first:
                    outF = open(currfile, 'w', encoding='utf-8')
                    first = False
                else:
                    if outF:
                        outF.close()
                    outF = open(currfile, 'w', encoding='utf-8')
                print(f"Created file {currfile}...")
                currfile = get_currfile_name(outfile_basename, filecount + start_index, outfile_ext)
            if not first and outF:
                outF.write(line)
        if outF:
            outF.close()
    if filecount == 0:
        os.remove(currfile)
        print(f'NOTE: Regular expression "{regexp}" was not matched in input file.')
    print(f"NOTE: Input file split into {filecount} files.")


def os_name():
    return platform.system()


def print_dict(dict_obj):
    for key, val in dict_obj.items():
        print(f"{key}: {val}")


def read_config(configFile):

    confDict = {}
    check_file(configFile)

    config = ConfigParser.RawConfigParser()
    config.read(configFile)

    for section in config.sections():
        for (key, val) in config.items(section):
            confDict[key] = val

    return confDict


def run_process(cmd, args):
    retcode = subprocess.call([cmd, args], stdin=PIPE, stdout=PIPE, stderr=STDOUT)
    return retcode


# EOF
