import os, json, re, sys
from collections import Counter
from pathlib import Path

projects_dir = Path(os.path.expanduser("~/.claude/projects"))
jsonl_files = sorted(projects_dir.rglob("*.jsonl"), key=lambda p: p.stat().st_mtime, reverse=True)[:50]
print(f"Scanning {len(jsonl_files)} files", file=sys.stderr)

bash_commands = Counter()
mcp_tools = Counter()

def leading_token(cmd):
    cmd = cmd.strip()
    cmd = re.sub(r"^(\w+=\S+\s+)+", "", cmd)
    tokens = cmd.split()
    if not tokens:
        return None
    if tokens[0] in ("sudo", "timeout") and len(tokens) > 1:
        tokens = tokens[1:]
    if len(tokens) >= 2 and not tokens[1].startswith("-"):
        return f"{tokens[0]} {tokens[1]}"
    return tokens[0] if tokens else None

for jf in jsonl_files:
    try:
        with open(jf, encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except:
                    continue
                if obj.get("type") != "assistant":
                    continue
                msg = obj.get("message", {})
                for item in msg.get("content", []):
                    if not isinstance(item, dict):
                        continue
                    if item.get("type") != "tool_use":
                        continue
                    name = item.get("name", "")
                    inp = item.get("input", {})
                    if name == "Bash":
                        cmd = inp.get("command", "")
                        tok = leading_token(cmd)
                        if tok:
                            bash_commands[tok] += 1
                    elif name.startswith("mcp__"):
                        mcp_tools[name] += 1
    except:
        pass

print("=== BASH ===")
for cmd, count in bash_commands.most_common(50):
    print(f"{count}\t{cmd}")
print("=== MCP ===")
for tool, count in mcp_tools.most_common(20):
    print(f"{count}\t{tool}")
