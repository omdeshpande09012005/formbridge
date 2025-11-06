@echo off
REM FormBridge Email Sender - Windows Batch Script
REM Sends an email via FormBridge API

setlocal enabledelayedexpansion

set API_URL=https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod/submit
set SENDER_EMAIL=om.deshpande@mitwpu.edu.in
set RECIPIENT_EMAIL=om.deshpande@mitwpu.edu.in
set TEMPLATE_PATH=.\email_templates\base.html

echo.
echo ===== FormBridge Email Sender =====
echo.

if not exist %TEMPLATE_PATH% (
    echo ERROR: Template not found at %TEMPLATE_PATH%
    exit /b 1
)

echo Loading template: %TEMPLATE_PATH%
for %%F in (%TEMPLATE_PATH%) do set TEMPLATE_SIZE=%%~zF
echo Template size: %TEMPLATE_SIZE% bytes
echo.

echo Sending email via FormBridge API...
echo API: %API_URL%
echo Recipient: %RECIPIENT_EMAIL%
echo.

REM Create temporary JSON file
(
    echo {
    echo   "form_id": "email-template-test",
    echo   "name": "Om Deshpande",
    echo   "email": "%SENDER_EMAIL%",
    echo   "message": "Testing FormBridge email template via API",
    echo   "page": "https://omdeshpande09012005.github.io/formbridge/"
    echo }
) > temp_payload.json

REM Send request using curl
curl -X POST %API_URL% ^
  -H "Content-Type: application/json" ^
  -d @temp_payload.json

REM Clean up
del temp_payload.json

echo.
echo SUCCESS! Email submitted via FormBridge API
echo Check inbox for the email
echo.
