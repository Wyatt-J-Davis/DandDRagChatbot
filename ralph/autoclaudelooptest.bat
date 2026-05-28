@echo off
setlocal enabledelayedexpansion

:: --- CONFIGURATION --- ::
:: %~dp0 automatically captures the exact folder this script lives in ("...\LocalAIAgent\ralph\")
set "SCRIPT_DIR=%~dp0"
:: This moves up one level from the script's folder, then targets user-stories\done
set "WATCH_DIR=%~dp0..\user-stories"
set "MY_ARG=instructions.md"
:: ---------------------

:LOOP
echo Starting the tool execution...

:: 1. Call the first script inside ralph while staying in the root context
call "%SCRIPT_DIR%generateprompt.bat" "%MY_ARG%"

:: 2. Call the second script inside ralph while staying in the root context
call "%SCRIPT_DIR%autoclauderemote.bat" "%MY_ARG%"

echo.
echo Watching for removed files in: %WATCH_DIR%

set "INITIAL_COUNT=0"
for %%A in ("%WATCH_DIR%\*") do set /a INITIAL_COUNT+=1

:WATCH
timeout /t 5 /nobreak >nul

set "CURRENT_COUNT=0"
for %%A in ("%WATCH_DIR%\*") do set /a CURRENT_COUNT+=1

:: If a file is added, update initial count to prevent a false loop trigger
if %CURRENT_COUNT% gtr %INITIAL_COUNT% (
    set "INITIAL_COUNT=%CURRENT_COUNT%"
    goto WATCH
)

:: Trigger only if current count is less than initial count
if %CURRENT_COUNT% lss %INITIAL_COUNT% goto TRIGGER

goto WATCH

:TRIGGER
echo File removal detected! Restarting scripts...
echo.
goto LOOP
