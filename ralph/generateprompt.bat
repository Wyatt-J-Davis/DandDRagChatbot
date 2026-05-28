:: Find the lowest-numbered open user story (sorted by filename, first match wins)
set "STORY_FILE="
for /f "delims=" %%F in ('dir /b /on "user-stories\*.md" 2^>nul') do (
    if not defined STORY_FILE set "STORY_FILE=user-stories\%%F"
)

if not defined STORY_FILE (
    echo No open user stories found.
    exit /b 0
)

echo Selected story: %STORY_FILE%

:: Build the prompt in an instructions file
set "TMPFILE=instructions.md"

(
    echo Previous commits:
    git log -n 5 --format="%%H%%n%%ad%%n%%B---" --date=short 2>nul || echo No commits found
    echo.
    echo User Story:
    type "%STORY_FILE%"
    echo.
    type ralph\dev-prompt.md
) > "%TMPFILE%"
