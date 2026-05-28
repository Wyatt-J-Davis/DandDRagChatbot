@echo off
setlocal enabledelayedexpansion

:: ============================================================
:: afk.bat  --  AFK Claude development loop
:: Usage:  afk.bat <iterations>
:: ============================================================

if "%~1"=="" (
    echo Usage: afk.bat ^<iterations^>
    echo   iterations  number of user-story sessions to run
    exit /b 1
)

set /a MAX=%~1
set /a COUNT=0

:loop
set /a COUNT+=1
if !COUNT! gtr %MAX% (
    echo.
    echo Reached %MAX% iteration(s^) without completing all issues.
    exit /b 0
)

echo.
echo === Iteration !COUNT! / %MAX% ===
echo.

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

:: Build the prompt in a temp file
set "TMPFILE=%TEMP%\ralph_prompt_%RANDOM%.txt"

(
    echo Previous commits:
    git log -n 5 --format="%%H%%n%%ad%%n%%B---" --date=short 2>nul || echo No commits found
    echo.
    echo User Story:
    type "%STORY_FILE%"
    echo.
    type ralph\dev-prompt.md
) > "%TMPFILE%"

:: Run claude, pipe the prompt via stdin
:: --output-format stream-json lets us detect the NO MORE TASKS sentinel
set "RESULT_FILE=%TEMP%\ralph_result_%RANDOM%.txt"

claude --permission-mode acceptEdits --print --verbose --output-format stream-json --remote-control < "%TMPFILE%" > "%RESULT_FILE%" 2>&1

:: Stream assistant text to the console (requires jq on PATH)
where jq >nul 2>&1
if %ERRORLEVEL% equ 0 (
    jq -rj "select(.type==\"assistant\").message.content[]? | select(.type==\"text\").text // empty" "%RESULT_FILE%"
) else (
    :: jq not available — just print the raw output
    type "%RESULT_FILE%"
)

:: Check for the NO MORE TASKS sentinel
findstr /i "NO MORE TASKS" "%RESULT_FILE%" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo.
    echo All AFK issues complete after !COUNT! iteration(s^).
    del "%TMPFILE%" "%RESULT_FILE%" 2>nul
    exit /b 0
)

del "%TMPFILE%" "%RESULT_FILE%" 2>nul

goto loop
