
$transcriptDir = "C:\Users\whyit\.claude\projects"
$jsonlFiles = Get-ChildItem -Path $transcriptDir -Filter "*.jsonl" -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -First 50

$bashCounts = @{}
$mcpCounts = @{}

foreach ($file in $jsonlFiles) {
    $lines = Get-Content $file.FullName -ErrorAction SilentlyContinue
    foreach ($line in $lines) {
        try {
            $obj = $line | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($obj.type -eq "assistant" -and $obj.message.content) {
                foreach ($content in $obj.message.content) {
                    if ($content.type -eq "tool_use") {
                        if ($content.name -eq "Bash" -and $content.input.command) {
                            $cmd = $content.input.command.Trim()
                            $tokens = ($cmd -split '\s+') | Where-Object { $_ -ne '' } | Select-Object -First 3
                            if ($tokens.Count -gt 0) {
                                $key = $tokens[0]
                                if ($tokens.Count -ge 2 -and $key -in @('git','gh','flutter','dart','npm','pip','pytest','python','python3')) {
                                    $key = "$($tokens[0]) $($tokens[1])"
                                }
                                if ($bashCounts.ContainsKey($key)) { $bashCounts[$key]++ } else { $bashCounts[$key] = 1 }
                            }
                        } elseif ($content.name -like "mcp__*") {
                            $key = $content.name
                            if ($mcpCounts.ContainsKey($key)) { $mcpCounts[$key]++ } else { $mcpCounts[$key] = 1 }
                        }
                    }
                }
            }
        } catch {}
    }
}

Write-Output "=== BASH COMMANDS ==="
$bashCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 40 | ForEach-Object { "$($_.Value) $($_.Key)" }
Write-Output ""
Write-Output "=== MCP TOOLS ==="
$mcpCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 20 | ForEach-Object { "$($_.Value) $($_.Key)" }
