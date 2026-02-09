#!/usr/bin/env python3

# (c) Shahar Valiano, 2017

import argparse

import utils


def parse_args():
    parser = argparse.ArgumentParser(
        description="Split a text file into multiple files at regex match points.")
    parser.add_argument("input_file", help="Path to the input text file")
    parser.add_argument("dest_folder", help="Destination folder for output files")
    parser.add_argument("regexp", help="Regular expression to split on")
    return parser.parse_args()


def main():
    args = parse_args()

    utils.check_file(args.input_file)
    utils.create_dir(args.dest_folder)
    utils.check_regexp(args.regexp)

    print("Script parameters:")
    print(f"* Input file:   {args.input_file}")
    print(f"* Results dir:  {args.dest_folder}")
    print(f"* Split regexp: {args.regexp}")

    utils.split_text(args.input_file, args.dest_folder, args.regexp)


if __name__ == '__main__':
    main()
