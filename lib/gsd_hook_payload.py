#!/usr/bin/env python3
"""Adapt native hook JSON to the command guard's four NUL-delimited fields.

Only a direct, simple GSD executable is classified. Shell syntax around a GSD
name is rejected: this adapter does not execute shell text or infer its effects.
"""

import json
import os
import re
import shlex
import sys


GSD_NAME = re.compile(r"^/?gsd-[a-z][a-z0-9-]*$")
GSD_MENTION = re.compile(r"gsd-[a-z][a-z0-9-]*")
SHELL_OPERATORS = {";", "&&", "&", "||", "|", ">", "<", ">>", "<<", "(", ")"}


def emit(kind, command="", args="", repo=""):
    sys.stdout.buffer.write("\0".join((kind, command, args, repo)).encode() + b"\0")


def directory(value, base):
    if not isinstance(value, str) or not value:
        return base
    return os.path.abspath(os.path.join(base, value))


def main():
    try:
        payload = json.load(sys.stdin)
        if not isinstance(payload, dict):
            raise ValueError("payload is not an object")
        tool = payload.get("tool_name")
        tool_input = payload.get("tool_input")
        if len(sys.argv) > 1 and sys.argv[1] == "--claude":
            if tool_input is None:
                tool_input = {}
            if not isinstance(tool_input, dict):
                raise ValueError("tool_input must be an object")
            command = payload.get("command_name", tool_input.get("skill", ""))
            args = payload.get("command_args", tool_input.get("args", ""))
            if not isinstance(command, str) or not isinstance(args, str):
                raise ValueError("command and arguments must be strings")
            if "\0" in command or "\0" in args:
                raise ValueError("NUL in hook command or arguments")
            command = command.lstrip("/")
            emit("guard" if command.startswith("gsd-") else "allow", command, args)
            return
        if tool not in ("activate_skill", "run_shell_command") or not isinstance(tool_input, dict):
            raise ValueError("missing Gemini tool fields")

        base = os.path.abspath(os.environ.get("GEMINI_PROJECT_DIR") or os.getcwd())
        repo = directory(payload.get("cwd"), base)
        repo = directory(tool_input.get("cwd"), repo)
        repo = directory(tool_input.get("directory"), repo)

        if tool == "activate_skill":
            name = tool_input.get("name")
            if not isinstance(name, str):
                raise ValueError("skill name is missing")
            command = name.removeprefix("/") if hasattr(name, "removeprefix") else name.lstrip("/")
            if not command.startswith("gsd-"):
                emit("allow")
                return
            if not GSD_NAME.fullmatch(name):
                raise ValueError("ambiguous GSD skill name")
            args = tool_input.get("args", "")
            if not isinstance(args, str):
                raise ValueError("GSD skill args must be a string")
            emit("guard", command, args, repo)
            return

        shell = tool_input.get("command")
        if not isinstance(shell, str):
            raise ValueError("shell command is missing")
        if not GSD_MENTION.search(shell):
            emit("allow")
            return
        try:
            lexer = shlex.shlex(shell, posix=True, punctuation_chars=";&|<>()")
            lexer.whitespace_split = True
            tokens = list(lexer)
        except ValueError:
            raise ValueError("unparseable shell command containing GSD")
        if not tokens or any(char in shell for char in "\n\r"):
            raise ValueError("ambiguous shell command containing GSD")
        if any(token in SHELL_OPERATORS or any(c in token for c in ";&|<>()") for token in tokens):
            raise ValueError("compound shell command containing GSD; run the GSD executable directly")
        if any(c in shell for c in "`$"):
            raise ValueError("shell expansion around GSD; run the GSD executable directly")
        executable = os.path.basename(tokens[0])
        if not GSD_NAME.fullmatch(executable):
            raise ValueError("GSD appears in a non-direct shell command; run the GSD executable directly")

        args = tokens[1:]
        if executable == "gsd-flow-next":
            phase = ""
            extras = []
            i = 0
            while i < len(args):
                token = args[i]
                if token == "--repo":
                    if i + 1 >= len(args):
                        raise ValueError("gsd-flow-next --repo needs a directory")
                    repo = directory(args[i + 1], repo)
                    i += 2
                    continue
                if token.startswith("--repo="):
                    repo = directory(token.split("=", 1)[1], repo)
                elif token == "--phase":
                    if i + 1 >= len(args):
                        raise ValueError("gsd-flow-next --phase needs a value")
                    phase = args[i + 1]
                    i += 2
                    continue
                elif not token.startswith("-"):
                    phase = token
                else:
                    extras.append(token)
                i += 1
            emit("guard", "gsd-flow", " ".join(([phase] if phase else []) + extras), repo)
        else:
            emit("guard", executable, " ".join(args), repo)
    except (ValueError, TypeError, json.JSONDecodeError) as exc:
        emit("block", str(exc))


if __name__ == "__main__":
    main()
