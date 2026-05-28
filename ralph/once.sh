#!/bin/bash

{
  echo "Previous commits:"
  git log -n 5 --format="%H%n%ad%n%B---" --date=short 2>/dev/null || echo "No commits found"
  echo ""
  echo "Issues:"
  cat user-stories/*.md 2>/dev/null || echo "No issues found"
  echo ""
  cat ralph/prompt.md
} | claude --permission-mode acceptEdits -
