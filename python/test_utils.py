#!/usr/bin/env python3

import io
import os
import sys
import textwrap

import pytest

import utils


# ---- strip_path ----

class TestStripPath:
    def test_full_path(self):
        assert utils.strip_path("/home/user/docs/file.txt") == "file.txt"

    def test_filename_only(self):
        assert utils.strip_path("file.txt") == "file.txt"

    def test_trailing_slash(self):
        assert utils.strip_path("/home/user/docs/") == "docs"

    def test_relative_path(self):
        assert utils.strip_path("docs/file.txt") == "file.txt"


# ---- eprint ----

class TestEprint:
    def test_prints_to_stderr(self, capsys):
        utils.eprint("error message")
        assert capsys.readouterr().err == "error message\n"

    def test_does_not_print_to_stdout(self, capsys):
        utils.eprint("error message")
        assert capsys.readouterr().out == ""

    def test_multiple_args(self, capsys):
        utils.eprint("hello", "world")
        assert capsys.readouterr().err == "hello world\n"


# ---- mkdir_p ----

class TestMkdirP:
    def test_creates_new_directory(self, tmp_path):
        new_dir = str(tmp_path / "newdir")
        assert utils.mkdir_p(new_dir) is True
        assert os.path.isdir(new_dir)

    def test_existing_directory_returns_true(self, tmp_path):
        assert utils.mkdir_p(str(tmp_path)) is True

    def test_invalid_path_returns_false(self):
        assert utils.mkdir_p("/nonexistent/parent/child") is False


# ---- regexp_is_valid ----

class TestRegexpIsValid:
    def test_valid_simple(self):
        assert utils.regexp_is_valid(r"hello") is True

    def test_valid_complex(self):
        assert utils.regexp_is_valid(r"^foo\d+.*bar$") is True

    def test_invalid_unbalanced_group(self):
        assert utils.regexp_is_valid(r"(unclosed") is False

    def test_invalid_bad_quantifier(self):
        assert utils.regexp_is_valid(r"*") is False

    def test_empty_string_is_valid(self):
        assert utils.regexp_is_valid("") is True


# ---- check_file ----

class TestCheckFile:
    def test_existing_file_does_not_exit(self, tmp_path):
        f = tmp_path / "exists.txt"
        f.write_text("data")
        utils.check_file(str(f))  # should not raise

    def test_nonexistent_file_exits(self, tmp_path):
        with pytest.raises(SystemExit) as exc_info:
            utils.check_file(str(tmp_path / "nope.txt"))
        assert exc_info.value.code == 1

    def test_directory_is_not_a_file(self, tmp_path):
        with pytest.raises(SystemExit):
            utils.check_file(str(tmp_path))


# ---- create_dir ----

class TestCreateDir:
    def test_creates_new_directory(self, tmp_path):
        new_dir = str(tmp_path / "newdir")
        utils.create_dir(new_dir)
        assert os.path.isdir(new_dir)

    def test_existing_directory_succeeds(self, tmp_path):
        utils.create_dir(str(tmp_path))  # should not raise

    def test_invalid_path_exits(self):
        with pytest.raises(SystemExit) as exc_info:
            utils.create_dir("/nonexistent/parent/child")
        assert exc_info.value.code == 1


# ---- check_regexp ----

class TestCheckRegexp:
    def test_valid_regexp_does_not_exit(self):
        utils.check_regexp(r"^hello\d+$")  # should not raise

    def test_invalid_regexp_exits(self):
        with pytest.raises(SystemExit) as exc_info:
            utils.check_regexp(r"(unclosed")
        assert exc_info.value.code == 1


# ---- cut_text ----

class TestCutText:
    def test_cuts_at_matching_line(self, tmp_path, capsys):
        f = tmp_path / "input.txt"
        f.write_text("line1\nline2\nSTOP here\nline4\n")
        result = utils.cut_text(str(f), r"STOP")
        assert result is True
        output = capsys.readouterr().out
        assert "line1" in output
        assert "line2" in output
        assert "STOP here" in output
        assert "line4" not in output

    def test_no_match_prints_all_lines(self, tmp_path, capsys):
        f = tmp_path / "input.txt"
        f.write_text("line1\nline2\nline3\n")
        result = utils.cut_text(str(f), r"NOMATCH")
        assert result is True
        output = capsys.readouterr().out
        assert "line1" in output
        assert "line2" in output
        assert "line3" in output

    def test_nonexistent_file_returns_false(self):
        result = utils.cut_text("/nonexistent/file.txt", r"test")
        assert result is False

    def test_invalid_regexp_returns_false(self, tmp_path):
        f = tmp_path / "input.txt"
        f.write_text("data\n")
        result = utils.cut_text(str(f), r"(unclosed")
        assert result is False


# ---- split_text ----

class TestSplitText:
    def test_splits_file_on_regexp(self, tmp_path, capsys):
        infile = tmp_path / "input.txt"
        infile.write_text("HEADER one\ndata1\nHEADER two\ndata2\n")
        resdir = tmp_path / "results"
        resdir.mkdir()
        result = utils.split_text(str(infile), str(resdir), r"^HEADER")
        assert result is None  # function doesn't return a value on success

        out1 = resdir / "out.001.txt"
        out2 = resdir / "out.002.txt"
        assert out1.exists()
        assert "HEADER one" in out1.read_text()
        assert "data1" in out1.read_text()
        assert out2.exists()
        assert "HEADER two" in out2.read_text()
        assert "data2" in out2.read_text()

    def test_no_match_produces_no_files(self, tmp_path, capsys):
        infile = tmp_path / "input.txt"
        infile.write_text("no match here\n")
        resdir = tmp_path / "results"
        resdir.mkdir()
        utils.split_text(str(infile), str(resdir), r"NOMATCH")
        # The initially created empty file should be removed
        assert not (resdir / "out.001.txt").exists()

    def test_nonexistent_infile_returns_false(self, tmp_path):
        resdir = tmp_path / "results"
        resdir.mkdir()
        result = utils.split_text("/nonexistent.txt", str(resdir), r"test")
        assert result is False

    def test_nonexistent_resdir_returns_false(self, tmp_path):
        infile = tmp_path / "input.txt"
        infile.write_text("data\n")
        result = utils.split_text(str(infile), "/nonexistent/dir", r"test")
        assert result is False

    def test_invalid_regexp_returns_false(self, tmp_path):
        infile = tmp_path / "input.txt"
        infile.write_text("data\n")
        resdir = tmp_path / "results"
        resdir.mkdir()
        result = utils.split_text(str(infile), str(resdir), r"(bad")
        assert result is False

    def test_single_match_produces_one_file(self, tmp_path, capsys):
        infile = tmp_path / "input.txt"
        infile.write_text("prefix\nSPLIT\nafter\n")
        resdir = tmp_path / "results"
        resdir.mkdir()
        utils.split_text(str(infile), str(resdir), r"SPLIT")
        out1 = resdir / "out.001.txt"
        assert out1.exists()
        content = out1.read_text()
        assert "SPLIT" in content
        assert "after" in content
        # "prefix" should not be in any output file (it's before the first match)
        assert "prefix" not in content


# ---- os_name ----

class TestOsName:
    def test_returns_string(self):
        result = utils.os_name()
        assert isinstance(result, str)
        assert len(result) > 0

    def test_matches_platform(self):
        import platform
        assert utils.os_name() == platform.system()


# ---- print_dict ----

class TestPrintDict:
    def test_prints_key_value_pairs(self, capsys):
        utils.print_dict({"name": "alice", "age": "30"})
        output = capsys.readouterr().out
        assert "name: alice" in output
        assert "age: 30" in output

    def test_empty_dict(self, capsys):
        utils.print_dict({})
        assert capsys.readouterr().out == ""


# ---- read_config ----

class TestReadConfig:
    def test_reads_ini_file(self, tmp_path):
        cfg = tmp_path / "test.ini"
        cfg.write_text(textwrap.dedent("""\
            [section1]
            key1 = value1
            key2 = value2

            [section2]
            key3 = value3
        """))
        result = utils.read_config(str(cfg))
        assert result == {"key1": "value1", "key2": "value2", "key3": "value3"}

    def test_nonexistent_file_exits(self):
        with pytest.raises(SystemExit):
            utils.read_config("/nonexistent/config.ini")

    def test_duplicate_keys_across_sections(self, tmp_path):
        cfg = tmp_path / "dup.ini"
        cfg.write_text(textwrap.dedent("""\
            [section1]
            key = first

            [section2]
            key = second
        """))
        result = utils.read_config(str(cfg))
        # Later section overwrites earlier one
        assert result["key"] == "second"


# ---- run_process ----

class TestRunProcess:
    def test_successful_command(self):
        retcode = utils.run_process("true", "")
        assert retcode == 0

    def test_failing_command(self):
        retcode = utils.run_process("false", "")
        assert retcode != 0
