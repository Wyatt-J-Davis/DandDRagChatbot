@echo off
setlocal

echo ============================================================
echo  Building ttrpg_backend executable (FastAPI)
echo ============================================================
echo.

set PYTHON=venv\Scripts\python.exe

if not exist "%PYTHON%" (
    echo ERROR: %PYTHON% not found. Create the venv and install requirements first.
    exit /b 1
)

if exist build rmdir /S /Q build
if exist dist rmdir /S /Q dist

"%PYTHON%" -m PyInstaller TTRPGChatbot.spec --noconfirm

set EXIT_CODE=%ERRORLEVEL%

echo.
if %EXIT_CODE% NEQ 0 (
    echo ============================================================
    echo  Build FAILED  ^(exit code %EXIT_CODE%^)
    echo ============================================================
    exit /b %EXIT_CODE%
)

echo ============================================================
echo  Build complete
echo  Executable: dist\ttrpg_backend\ttrpg_backend.exe
echo ============================================================

endlocal
