import json
from pathlib import Path

projects_dir = Path.home() / ".claude" / "projects"
jsonl_files = sorted(
    projects_dir.rglob("*.jsonl"),
    key=lambda p: p.stat().st_mtime,
    reverse=True
)[:50]

bash_commands = []
mcp_tools = []

for f in jsonl_files:
    try:
        for line in f.read_text(encoding="utf-8", errors="ignore").splitlines():
            try:
                obj = json.loads(line)
                msg = obj.get("message", {})
                if msg.get("role") == "assistant":
                    for block in msg.get("content", []):
                        if block.get("type") != "tool_use":
                            continue
                        name = block.get("name", "")
                        if name == "Bash":
                            cmd = block.get("input", {}).get("command", "")
                            if cmd:
                                bash_commands.append(cmd[:300])
                        elif name.startswith("mcp__"):
                            mcp_tools.append(name)
            except:
                pass
    except:
        pass

print("=== BASH ===")
for c in bash_commands:
    print(c[:200])
print("=== MCP ===")
for t in mcp_tools:
    print(t)
