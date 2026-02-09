#!/usr/bin/env python3

# (c) Shahar Valiano, 2018

import configparser
import platform
import re
import subprocess
import sys
from pathlib import Path
from subprocess import PIPE, STDOUT


# -----------------------------------------------------------------------------
# Utility functions
# -----------------------------------------------------------------------------


def strip_path(full_path):
    return Path(full_path).name


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


def mkdir_p(dirname):
    try:
        Path(dirname).mkdir(exist_ok=True)
        return True
    except OSError:
        return False


def regexp_is_valid(regexp):
    try:
        re.compile(regexp)
        return True
    except re.error:
        return False


def check_file(infile):
    if not Path(infile).is_file():
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
    if not Path(infile).is_file() or not regexp_is_valid(regexp):
        return False
    compiled_regexp = re.compile(regexp)
    with open(infile, encoding='utf-8') as f:
        for line in f:
            print(line.strip())
            if compiled_regexp.search(line):
                break
    return True


def split_text(infile, resdir, regexp):
    if not Path(infile).is_file() or not Path(resdir).is_dir():
        return False
    if not regexp_is_valid(regexp):
        return False

    compiled_regexp = re.compile(regexp)
    resdir = Path(resdir)
    filecount = 0
    out_file = None

    print("\nProcessing...\n")

    try:
        with open(infile, encoding='utf-8') as in_file:
            for line in in_file:
                if compiled_regexp.search(line):
                    if out_file:
                        out_file.close()
                    filecount += 1
                    path = resdir / f"out.{filecount:03d}.txt"
                    out_file = open(path, 'w', encoding='utf-8')
                    print(f"Created file {path}...")
                if out_file:
                    out_file.write(line)
    finally:
        if out_file:
            out_file.close()

    if filecount == 0:
        print(f'NOTE: Regular expression "{regexp}" was not matched in input file.')
    print(f"NOTE: Input file split into {filecount} files.")


def os_name():
    return platform.system()


def print_dict(dict_obj):
    for key, val in dict_obj.items():
        print(f"{key}: {val}")


def read_config(config_file):
    conf_dict = {}
    check_file(config_file)

    config = configparser.RawConfigParser()
    config.read(config_file)

    for section in config.sections():
        for key, val in config.items(section):
            conf_dict[key] = val

    return conf_dict


def run_process(cmd, args):
    result = subprocess.run([cmd, args], stdin=PIPE, stdout=PIPE, stderr=STDOUT, check=False)
    return result.returncode
