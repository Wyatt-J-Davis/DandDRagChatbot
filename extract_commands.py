#!/usr/bin/env python3
"""Extract and count Bash tool calls from Claude transcript JSONL files."""
import json
import os
import re
from collections import Counter
from pathlib import Path

PROJECTS_DIR = Path.home() / ".claude" / "projects"
SKIP_AUTO_ALLOWED = {
    "cal", "uptime", "cat", "head", "tail", "wc", "stat", "strings",
    "hexdump", "od", "nl", "id", "uname", "free", "df", "du", "locale",
    "groups", "nproc", "basename", "dirname", "realpath", "cut", "paste",
    "tr", "column", "tac", "rev", "fold", "expand", "unexpand", "fmt",
    "comm", "cmp", "numfmt", "readlink", "diff", "true", "false", "sleep",
    "which", "type", "expr", "test", "getconf", "seq", "tsort", "pr",
    "echo", "printf", "ls", "cd", "find",
}

GIT_READ_ONLY = {"status", "log", "diff", "show", "blame", "branch", "tag",
                  "remote", "ls-files", "ls-remote", "rev-parse", "describe",
                  "stash", "reflog", "shortlog", "cat-file", "for-each-ref",
                  "worktree"}

GH_READ_ONLY = {"pr", "issue", "run", "workflow", "repo", "release", "auth", "api"}

INTERPRETERS = {"python", "python3", "python3.exe", "node", "bun", "deno",
                "ruby", "perl", "php", "lua", "bash", "sh", "zsh", "fish",
                "eval", "exec", "ssh", "npx", "bunx", "uvx"}

DESTRUCTIVE = {"rm", "rmdir", "mv", "cp", "touch", "mkdir", "chmod",
               "chown", "truncate", "tee", "write", "install", "pip",
               "pip3", "npm", "yarn", "pnpm", "cargo", "make", "cmake",
               "git", "gh"}

def get_leading_token(cmd: str) -> str:
    cmd = cmd.strip()
    cmd = re.sub(r'^([A-Z_][A-Z0-9_]*=[^\s]* )+', '', cmd)
    for prefix in ("sudo ", "timeout "):
        if cmd.startswith(prefix):
            cmd = cmd[len(prefix):].lstrip()
    parts = cmd.split()
    return parts[0] if parts else ""

def classify_command(cmd: str):
    cmd = cmd.strip()
    if not cmd:
        return None
    first = re.split(r'[|;&\n]', cmd)[0].strip()
    leading = get_leading_token(first)
    tokens = first.split()
    if not leading or leading in SKIP_AUTO_ALLOWED:
        return None
    if leading in INTERPRETERS:
        return None
    if leading in DESTRUCTIVE:
        return None

    # venv/Scripts pytest
    if re.search(r'venv[/\\]Scripts[/\\]python\.exe\s+-m\s+pytest', first):
        return "Bash(venv/Scripts/python.exe -m pytest *)"
    if re.search(r'venv[/\\]bin[/\\]python\s+-m\s+pytest', first):
        return "Bash(venv/bin/python -m pytest *)"

    if leading in ("run_tests.bat",):
        return "Bash(run_tests.bat)"

    if leading == "flutter":
        if len(tokens) >= 2 and tokens[1] in ("analyze", "test", "pub", "build"):
            return f"Bash(flutter {tokens[1]} *)"
        return None

    if leading == "dart":
        if len(tokens) >= 2 and tokens[1] in ("analyze", "test", "pub"):
            return f"Bash(dart {tokens[1]} *)"
        return None

    return None


def extract_bash_commands(jsonl_path):
    commands = []
    try:
        with open(jsonl_path, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                msg = obj.get("message", {})
                if msg.get("role") != "assistant":
                    continue
                for block in msg.get("content", []):
                    if block.get("type") == "tool_use" and block.get("name") == "Bash":
                        cmd = block.get("input", {}).get("command", "")
                        if cmd:
                            commands.append(cmd)
    except Exception:
        pass
    return commands


def main():
    all_files = []
    for root, dirs, files in os.walk(PROJECTS_DIR):
        depth = str(root).count(os.sep) - str(PROJECTS_DIR).count(os.sep)
        if depth > 3:
            dirs.clear()
            continue
        for f in files:
            if f.endswith(".jsonl"):
                p = Path(root) / f
                try:
                    mtime = p.stat().st_mtime
                    all_files.append((mtime, p))
                except Exception:
                    pass

    all_files.sort(reverse=True)
    top_files = [p for _, p in all_files[:50]]

    counter = Counter()
    raw_counter = Counter()

    for fpath in top_files:
        for cmd in extract_bash_commands(fpath):
            key = cmd.strip()[:100]
            raw_counter[key] += 1
            pattern = classify_command(cmd)
            if pattern:
                counter[pattern] += 1

    print("TOP_RAW:")
    for cmd, count in raw_counter.most_common(40):
        print(f"{count}\t{cmd}")

    print("\nPATTERNS:")
    for pattern, count in counter.most_common(20):
        print(f"{count}\t{pattern}")


if __name__ == "__main__":
    main()
