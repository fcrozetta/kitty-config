"""Tests for the pure backend-resolution logic in kittens/sophie.py."""

import importlib.util
from pathlib import Path

import pytest

_spec = importlib.util.spec_from_file_location(
    "sophie_kitten", Path(__file__).resolve().parent.parent / "kittens" / "sophie.py"
)
sophie_kitten = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(sophie_kitten)

resolve = sophie_kitten.resolve
UsageError = sophie_kitten.UsageError

CLAUDE = ["claude", "--agent", "sophie"]
HERMES = ["hermes", "-p", "sophie"]


# --- explicit selector ---

def test_claude_flag():
    assert resolve(["--claude"], {}) == CLAUDE


def test_hermes_flag():
    assert resolve(["--hermes"], {}) == HERMES


def test_selector_is_stripped_and_rest_forwarded():
    assert resolve(["--claude", "-p", "status"], {}) == CLAUDE + ["-p", "status"]
    assert resolve(["--hermes", "-z", "status"], {}) == HERMES + ["-z", "status"]


def test_selector_beats_env():
    assert resolve(["--hermes"], {"SOPHIE_DEFAULT": "claude"}) == HERMES


# --- default backend ---

def test_no_args_no_env_defaults_to_claude():
    assert resolve([], {}) == CLAUDE


def test_env_selects_hermes():
    assert resolve([], {"SOPHIE_DEFAULT": "hermes"}) == HERMES


def test_env_selects_claude():
    assert resolve([], {"SOPHIE_DEFAULT": "claude"}) == CLAUDE


def test_empty_env_falls_back_to_claude():
    assert resolve([], {"SOPHIE_DEFAULT": ""}) == CLAUDE
    assert resolve([], {"SOPHIE_DEFAULT": "  "}) == CLAUDE


def test_env_value_is_trimmed():
    assert resolve([], {"SOPHIE_DEFAULT": " hermes "}) == HERMES


def test_unknown_env_value_raises():
    with pytest.raises(UsageError) as e:
        resolve([], {"SOPHIE_DEFAULT": "gpt"})
    assert "SOPHIE_DEFAULT" in str(e.value)


def test_env_value_is_case_sensitive():
    # Loud beats guessing: a typo should not silently pick a backend.
    with pytest.raises(UsageError):
        resolve([], {"SOPHIE_DEFAULT": "Claude"})


# --- args forwarded under the default backend ---

def test_bare_args_go_to_default_backend_verbatim():
    assert resolve(["-p", "hi"], {}) == CLAUDE + ["-p", "hi"]
    assert resolve(["-z", "hi"], {"SOPHIE_DEFAULT": "hermes"}) == HERMES + ["-z", "hi"]


# --- selector position ---

def test_selector_only_honoured_first():
    # A prompt mentioning a backend name must not be misrouted.
    assert resolve(["-p", "--claude"], {"SOPHIE_DEFAULT": "hermes"}) == HERMES + [
        "-p",
        "--claude",
    ]


def test_prompt_word_claude_is_not_a_selector():
    assert resolve(["-p", "is claude down?"], {}) == CLAUDE + ["-p", "is claude down?"]


def test_near_miss_flag_is_forwarded_not_rewritten():
    # A selector look-alike is the backend's problem, not ours.
    assert resolve(["--Claude"], {}) == CLAUDE + ["--Claude"]


def test_unrelated_double_dash_flag_is_forwarded():
    assert resolve(["--help"], {}) == CLAUDE + ["--help"]


def test_double_dash_passthrough():
    assert resolve(["--", "--claude"], {}) == CLAUDE + ["--", "--claude"]


# --- the returned list is independent of the module tables ---

def test_result_does_not_alias_backend_table():
    first = resolve(["--claude", "x"], {})
    first.append("mutated")
    assert resolve(["--claude"], {}) == CLAUDE
