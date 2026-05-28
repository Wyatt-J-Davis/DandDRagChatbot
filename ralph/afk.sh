#!/bin/bash
set -eo pipefail

if [ -z "$1" ]; then
  echo "Usage: $0 <iterations> [--remote-control]"
  echo "  --remote-control: enable remote control for each iteration"
  exit 1
fi

REMOTE_CONTROL=""
if [[ "$2" == "--remote-control" ]]; then
  REMOTE_CONTROL="--remote-control"
fi

# jq filter to extract streaming text from assistant messages
stream_text='select(.type == "assistant").message.content[]? | select(.type == "text").text // empty | gsub("\n"; "\r\n") | . + "\r\n\n"'

# jq filter to extract final result
final_result='select(.type == "result").result // empty'

for ((i=1; i<=$1; i++)); do
  echo ""
  echo "=== Iteration $i / $1 ==="
  echo ""

  tmpfile=$(mktemp)
  trap "rm -f $tmpfile" EXIT

  {
    echo "Previous commits:"
    git log -n 5 --format="%H%n%ad%n%B---" --date=short 2>/dev/null || echo "No commits found"
    echo ""
    echo "Issues:"
    cat user-stories/*.md 2>/dev/null || echo "No issues found"
    echo ""
    cat ralph/prompt.md
  } | claude \
    --permission-mode acceptEdits \
    --verbose \
    --print \
    --output-format stream-json \
    $REMOTE_CONTROL \
  | grep --line-buffered '^{' \
  | tee "$tmpfile" \
  | jq --unbuffered -rj "$stream_text"

  result=$(jq -r "$final_result" "$tmpfile")

  if [[ "$result" == *"<promise>NO MORE TASKS</promise>"* ]]; then
    echo ""
    echo "All AFK issues complete after $i iteration(s)."
    exit 0
  fi
done

echo ""
echo "Reached $1 iteration(s) without completing all issues."
