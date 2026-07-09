"""Tests for the pure file-manipulation logic in kittens/alias.py."""

import importlib.util
from pathlib import Path

_spec = importlib.util.spec_from_file_location(
    "alias_kitten", Path(__file__).resolve().parent.parent / "kittens" / "alias.py"
)
alias_kitten = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(alias_kitten)

zsh_quote = alias_kitten.zsh_quote
valid_name = alias_kitten.valid_name
valid_value = alias_kitten.valid_value
upsert_lines = alias_kitten.upsert_lines
remove_lines = alias_kitten.remove_lines
alias_lines = alias_kitten.alias_lines


# --- zsh_quote ---

def test_quote_plain():
    assert zsh_quote("git status") == "'git status'"


def test_quote_embedded_single_quote():
    assert zsh_quote("echo 'hi'") == "'echo '\\''hi'\\'''"


def test_quote_empty():
    assert zsh_quote("") == "''"


# --- valid_name ---

def test_valid_names():
    for name in ("gs", "git-st", "g.s", "G_2", "ll"):
        assert valid_name(name), name


def test_invalid_names():
    for name in ("", "a b", "a=b", "a$b", "ls*", "a'b"):
        assert not valid_name(name), name


# --- valid_value ---

def test_value_rejects_newline():
    assert not valid_value("git status\nrm -rf /")


def test_value_accepts_normal():
    assert valid_value("git status -sb")


# --- upsert_lines ---

def test_upsert_into_empty():
    lines, old = upsert_lines([], "gs", "git status")
    assert lines == ["alias gs='git status'"]
    assert old is None


def test_upsert_inserts_sorted():
    start = ["alias aa='1'", "alias zz='2'"]
    lines, old = upsert_lines(start, "mm", "3")
    assert lines == ["alias aa='1'", "alias mm='3'", "alias zz='2'"]
    assert old is None


def test_upsert_replaces_existing_in_place():
    start = ["alias aa='1'", "alias gs='git status'", "alias zz='2'"]
    lines, old = upsert_lines(start, "gs", "git status -sb")
    assert lines == ["alias aa='1'", "alias gs='git status -sb'", "alias zz='2'"]
    assert old == "'git status'"


def test_upsert_collapses_duplicates():
    start = ["alias gs='old1'", "alias gs='old2'"]
    lines, old = upsert_lines(start, "gs", "new")
    assert lines == ["alias gs='new'"]
    assert old == "'old1'"


def test_upsert_preserves_non_alias_lines():
    start = ["# my comment", "export FOO=1", "alias zz='2'"]
    lines, _ = upsert_lines(start, "aa", "1")
    assert "# my comment" in lines
    assert "export FOO=1" in lines
    assert lines.index("alias aa='1'") < lines.index("alias zz='2'")


def test_upsert_new_alias_appends_when_no_alias_lines():
    start = ["# header only"]
    lines, _ = upsert_lines(start, "gs", "git status")
    assert lines == ["# header only", "alias gs='git status'"]


# --- remove_lines ---

def test_remove_existing():
    start = ["alias aa='1'", "alias gs='git status'"]
    lines, found = remove_lines(start, "gs")
    assert lines == ["alias aa='1'"]
    assert found


def test_remove_missing():
    start = ["alias aa='1'"]
    lines, found = remove_lines(start, "gs")
    assert lines == start
    assert not found


def test_remove_all_duplicates():
    start = ["alias gs='1'", "alias gs='2'"]
    lines, found = remove_lines(start, "gs")
    assert lines == []
    assert found


def test_remove_preserves_non_alias_lines():
    start = ["# comment", "alias gs='1'", "export FOO=1"]
    lines, found = remove_lines(start, "gs")
    assert lines == ["# comment", "export FOO=1"]
    assert found


def test_remove_does_not_match_prefix():
    start = ["alias gsx='1'"]
    lines, found = remove_lines(start, "gs")
    assert lines == start
    assert not found


# --- alias_lines ---

def test_alias_lines_filters():
    start = ["# comment", "alias gs='1'", "export FOO=1", "alias ll='ls -la'"]
    assert alias_lines(start) == ["alias gs='1'", "alias ll='ls -la'"]
