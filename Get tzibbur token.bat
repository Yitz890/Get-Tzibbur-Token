@echo off
setlocal enabledelayedexpansion

:: Ask for user input
set /p NICKNAME=Whats your Tzibbur nickname: 
set /p PHONE=Whats your phone number (with +, e.g. +15550100123): 

echo Sending verification code...

:: Step 1: Request SMS code
curl -s -X POST "https://api.tzibbur.me/v1/auth/start" -H "Content-Type: application/json" -d "{\"phone\": \"%PHONE%\", \"displayName\": \"%NICKNAME%\", \"region\": \"US\", \"platform\": \"android\", \"deviceModel\": \"batch\"}" > %TEMP%\challenge.txt

:: Extract challengeId using PowerShell (robust JSON parsing)
for /f "delims=" %%i in ('powershell -Command "$json = Get-Content %TEMP%\challenge.txt | ConvertFrom-Json; Write-Output $json.challengeId"') do set CHALLENGE_ID=%%i

if "%CHALLENGE_ID%"=="" (
    echo Failed to get challenge ID. Response was:
    type %TEMP%\challenge.txt
    pause
    exit /b 1
)

echo Code sent! Check your SMS for the 6-digit code.

:: Ask for the code
set /p CODE=Enter the 6-digit verification code: 

echo Verifying...

:: Step 2: Verify code
curl -s -X POST "https://api.tzibbur.me/v1/auth/verify" -H "Content-Type: application/json" -d "{\"challengeId\": \"%CHALLENGE_ID%\", \"code\": \"%CODE%\", \"phone\": \"%PHONE%\", \"displayName\": \"%NICKNAME%\", \"region\": \"US\", \"platform\": \"android\", \"deviceModel\": \"batch\"}" > %TEMP%\verify.txt

:: Extract token using PowerShell (robust JSON parsing)
for /f "delims=" %%i in ('powershell -Command "$json = Get-Content %TEMP%\verify.txt | ConvertFrom-Json; Write-Output $json.token"') do set TOKEN=%%i

:: Check if token is empty
if "%TOKEN%"=="" (
    echo Verification failed. Response was:
    type %TEMP%\verify.txt
    echo.
    echo Press any key to exit...
    pause
    exit /b 1
)

:: ------------------------------------------
:: SUCCESS: Show token and PAUSE
:: ------------------------------------------
echo.
echo ========================================
echo Your Tzibbur access token is:
echo %TOKEN%
echo ========================================
echo.
echo Copy this token now. You will need it to send messages.
echo.

:: First pause - keeps window open so you can copy the token
echo Press any key to clean up temporary files...
pause

:: Clean up
del %TEMP%\challenge.txt %TEMP%\verify.txt 2>nul

:: Second pause - keeps window open until you manually close it
echo.
echo All done. Press any key to close this window...
pause