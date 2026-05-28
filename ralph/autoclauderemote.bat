@echo off
if "%~1"=="" (
    echo Error: Please provide an instruction text or a file path.
    exit /b
)

set "vbsFile=%temp%\claudetyper.vbs"

:: Step 1: Put the input onto the clipboard
if exist "%~1" (
    :: It's a file - pipe its content to the clipboard
    type "%~1" | clip
) else (
    :: It's raw text - echo it to the clipboard
    echo %*| clip
)

:: Step 2: Create the VBScript to launch Claude and hit Paste
echo Set wshShell = WScript.CreateObject("WScript.Shell") > "%vbsFile%"
echo wshShell.Run "cmd.exe /k claude", 1 >> "%vbsFile%"
:: Wait 2.5 seconds for Claude Code to fully boot up
echo WScript.Sleep 2500 >> "%vbsFile%"
:: Send Ctrl+V (represented by ^v in SendKeys)
echo wshShell.SendKeys "^v" >> "%vbsFile%"

:: Give the system 1.5 seconds to process the pasted text structure
echo WScript.Sleep 1500 >> "%vbsFile%"

:: Send the first Enter key strike
echo wshShell.SendKeys "~" >> "%vbsFile%"

:: Wait exactly 2 seconds before the second strike
echo WScript.Sleep 2000 >> "%vbsFile%"

:: Send the second Enter key strike
echo wshShell.SendKeys "~" >> "%vbsFile%"

:: --- NEW AUTOMATION SECTION ---
:: Wait exactly 1 second after submitting the prompt
echo WScript.Sleep 1000 >> "%vbsFile%"

:: Type the remote control slash command and hit enter
echo wshShell.SendKeys "/remote-control~" >> "%vbsFile%"
:: -------------------------------

:: Step 3: Run the automation and clean up
cscript //nologo "%vbsFile%"
del "%vbsFile%"
