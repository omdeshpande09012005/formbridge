@echo off
REM FormBridge Analytics Dashboard - Quick Setup Script (Windows)
REM Run this script to set up the analytics dashboard

setlocal enabledelayedexpansion

echo.
echo 📊 FormBridge Analytics Dashboard - Quick Setup
echo ================================================
echo.

REM Check if config.js exists
if exist "dashboard\config.js" (
    echo ✅ dashboard\config.js already exists
    set /p RECREATE="Do you want to recreate it? (y/n): "
    if /i not "!RECREATE!"=="y" (
        echo Skipping config creation
        echo.
        exit /b 0
    )
)

REM Copy config template
echo 📋 Creating dashboard\config.js from template...
if exist "dashboard\config.example.js" (
    copy "dashboard\config.example.js" "dashboard\config.js" > nul
    echo ✅ Created: dashboard\config.js
) else (
    echo ❌ Error: dashboard\config.example.js not found
    exit /b 1
)

echo.

REM Try to open with VS Code
if exist "%APPDATA%\Code\bin\code.cmd" (
    echo 🔧 Opening dashboard\config.js in VS Code...
    code "dashboard\config.js"
) else (
    echo ⚠️  Open dashboard\config.js in your text editor
    echo    Try: code dashboard\config.js
)

echo.
echo 📝 Next steps:
echo 1. Update API_URL in dashboard\config.js:
echo    - Development: http://127.0.0.1:3000
echo    - Production: https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/Prod
echo.
echo 2. Set DEFAULT_FORM_ID to your form ID (e.g., 'portfolio-contact')
echo.
echo 3. Optional: Add API_KEY if using production authentication
echo.
echo 4. Save and open dashboard in browser:
echo    start dashboard\index.html
echo.
echo 📖 See docs\DASHBOARD_README.md for detailed configuration
echo.
