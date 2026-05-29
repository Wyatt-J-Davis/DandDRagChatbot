@echo off
setlocal

echo ============================================================
echo  Running Python tests with coverage
echo ============================================================
echo.

venv\Scripts\python.exe -m pytest tests/ --cov --cov-report=term-missing --cov-report=html -v

set EXIT_CODE=%ERRORLEVEL%

echo.
if %EXIT_CODE% NEQ 0 (
    echo ============================================================
    echo  Python tests FAILED  ^(exit code %EXIT_CODE%^)
    echo ============================================================
    exit /b %EXIT_CODE%
)

echo ============================================================
echo  Running Flutter tests
echo ============================================================
echo.

pushd ui
flutter test --concurrency=1
set FLUTTER_EXIT=%ERRORLEVEL%
popd

echo.
if %FLUTTER_EXIT% NEQ 0 (
    echo ============================================================
    echo  Flutter tests FAILED  ^(exit code %FLUTTER_EXIT%^)
    echo ============================================================
    exit /b %FLUTTER_EXIT%
)

echo ============================================================
echo  All tests passed
echo  HTML report: tests\coverage_report\index.html
echo ============================================================

start "" "tests\coverage_report\index.html"

endlocal
