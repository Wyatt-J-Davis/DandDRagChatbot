@echo off
setlocal

echo ============================================================
echo  TTRPGChatbot  --  Full distribution build
echo ============================================================
echo.
echo  Steps:
echo    1. Build FastAPI backend  (PyInstaller)
echo    2. Build Flutter frontend (flutter build windows --release)
echo    3. Assemble dist\TTRPGChatbotApp\
echo.

set PYTHON=venv\Scripts\python.exe
set FLUTTER_RELEASE=ui\build\windows\x64\runner\Release
set DIST_DIR=dist\TTRPGChatbotApp

:: -- Sanity checks ----------------------------------------------------------

if not exist "%PYTHON%" (
    echo ERROR: %PYTHON% not found. Create the venv and install requirements first.
    exit /b 1
)

where flutter >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: flutter not found on PATH. Install the Flutter SDK first.
    exit /b 1
)

:: -- Step 1: Build FastAPI backend ------------------------------------------

echo [1/3] Building FastAPI backend...
echo.

if exist build rmdir /S /Q build
if exist dist\ttrpg_backend rmdir /S /Q dist\ttrpg_backend

"%PYTHON%" -m PyInstaller TTRPGChatbot.spec --noconfirm
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: PyInstaller build failed.
    exit /b 1
)

echo.
echo [1/3] Done -- dist\ttrpg_backend\ttrpg_backend.exe
echo.

:: -- Step 2: Build Flutter frontend -----------------------------------------

echo [2/3] Building Flutter Windows release...
echo.

pushd ui
cmd /c "flutter build windows --release"
set FLUTTER_EXIT=%ERRORLEVEL%
popd

if %FLUTTER_EXIT% NEQ 0 (
    echo.
    echo ERROR: Flutter build failed.
    exit /b 1
)

echo.
echo [2/3] Done -- %FLUTTER_RELEASE%\ttrpg_chatbot.exe
echo.

:: -- Step 3: Assemble distributable folder ----------------------------------

echo [3/3] Assembling %DIST_DIR%...
echo.

if exist "%DIST_DIR%" rmdir /S /Q "%DIST_DIR%"
mkdir "%DIST_DIR%"

:: Copy entire Flutter Release output (exe + dlls + data/)
xcopy /E /I /Y "%FLUTTER_RELEASE%\*" "%DIST_DIR%\" >nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Failed to copy Flutter output.
    exit /b 1
)

:: Copy PyInstaller backend bundle into backend\ subfolder
mkdir "%DIST_DIR%\backend"
xcopy /E /I /Y "dist\ttrpg_backend\*" "%DIST_DIR%\backend\" >nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Failed to copy backend bundle.
    exit /b 1
)

echo.
echo ============================================================
echo  Build complete!
echo.
echo  Distributable: %DIST_DIR%\
echo    ttrpg_chatbot.exe        (Flutter UI -- double-click to launch)
echo    backend\ttrpg_backend.exe (FastAPI backend, spawned automatically)
echo ============================================================

endlocal
