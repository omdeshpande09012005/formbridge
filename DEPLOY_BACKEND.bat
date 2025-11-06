@echo off
REM FormBridge Backend Deployment Script for Windows
REM This script builds and deploys the backend with updated configuration

setlocal enabledelayedexpansion

echo.
echo ========================================
echo   FormBridge Backend Deployment
echo ========================================
echo.

REM Check if we're in the right directory
if not exist "backend\template.yaml" (
    echo ERROR: backend\template.yaml not found
    echo Please run this script from the formbridge root directory
    exit /b 1
)

echo Checking AWS credentials...
aws sts get-caller-identity >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: AWS credentials not configured
    echo Please configure AWS credentials first
    exit /b 1
)

echo AWS credentials OK
echo.

REM Change to backend directory
cd backend

echo Step 1: Building SAM application...
echo.
sam build

if %errorlevel% neq 0 (
    echo ERROR: SAM build failed
    exit /b 1
)

echo.
echo Step 2: Deploying to AWS...
echo This may take 2-5 minutes...
echo.

sam deploy ^
    --stack-name formbridge-stack ^
    --capabilities CAPABILITY_IAM ^
    --no-confirm-changeset ^
    --no-fail-on-empty-changeset

if %errorlevel% eq 0 (
    echo.
    echo ========================================
    echo   Deployment Complete!
    echo ========================================
    echo.
    echo Your FormBridge backend is now deployed with:
    echo   - SES Sender: omdeshpande123456789@gmail.com
    echo   - Recipients: om.deshpande@mitwpu.edu.in
    echo   - CORS Enabled: https://omdeshpande09012005.github.io/formbridge/
    echo   - API: https://12mse3zde5.execute-api.ap-south-1.amazonaws.com/Prod
    echo.
    echo You can now test the contact form at:
    echo   https://omdeshpande09012005.github.io/formbridge/contact.html
    echo.
) else (
    echo ERROR: Deployment failed
    exit /b 1
)
