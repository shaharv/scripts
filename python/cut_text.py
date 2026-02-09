#!/usr/bin/env python3

# (c) Shahar Valiano, 2017

import argparse

import utils


def parse_args():
    parser = argparse.ArgumentParser(
        description="Read a text file and print lines up to the first regex match.")
    parser.add_argument("input_file", help="Path to the input text file")
    parser.add_argument("regexp", help="Regular expression to match")
    return parser.parse_args()


def main():
    args = parse_args()

    utils.check_file(args.input_file)
    utils.check_regexp(args.regexp)

    print("Script parameters:")
    print(f"* Input text file:     {args.input_file}")
    print(f"* Regexp to cut after: {args.regexp}")

    utils.cut_text(args.input_file, args.regexp)


if __name__ == '__main__':
    main()
