@echo off
setlocal EnableDelayedExpansion
:: ============================================================
::  FOR REPO OWNER USE ONLY
::  Run this to package the server binaries into a zip
::  that you then upload as a GitHub Release asset.
::
::  Set BIN_SRC and ADB_SRC to match your local paths.
:: ============================================================

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"

:: ============================================================
::  OWNER: Edit these two paths to match YOUR machine.
::  BIN_SRC = where your compiled server binaries are
::  ADB_SRC = where your extracted ADB SQL files are
:: ============================================================
set "BIN_SRC=%ROOT%\server"
set "ADB_SRC="
echo.
echo  Locate your ADB SQL files (ADB_735.10_world.sql / ADB_735.10_hotfix.sql).
set /p "ADB_SRC=  Full path to ADB folder (e.g. C:\WoWDev\ADB): "
if not exist "!ADB_SRC!\ADB_735.10_world.sql" (
    echo  [!] ADB_735.10_world.sql not found in: !ADB_SRC!
    pause & exit /b 1
)
:: ============================================================

set "OUT_ZIP=%ROOT%\server_binaries.zip"
set "OUT_DB_ZIP=%ROOT%\databases.zip"
set "RELEASE_TAG=v1.0"

echo.
echo [*] Creating server_binaries.zip from %BIN_SRC% ...

powershell -Command ^
  "$b='%BIN_SRC%'; $files = @(" ^
  "  \"$b\worldserver.exe\"," ^
  "  \"$b\bnetserver.exe\"," ^
  "  \"$b\connection_patcher.exe\"," ^
  "  \"$b\mapextractor.exe\"," ^
  "  \"$b\vmap4extractor.exe\"," ^
  "  \"$b\vmap4assembler.exe\"," ^
  "  \"$b\mmaps_generator.exe\"," ^
  "  \"$b\libcrypto-3-x64.dll\"," ^
  "  \"$b\libmysql.dll\"," ^
  "  \"$b\libssl-3-x64.dll\"," ^
  "  \"$b\bnetserver.cert.pem\"," ^
  "  \"$b\bnetserver.key.pem\"," ^
  "  \"$b\worldserver.conf.dist\"," ^
  "  \"$b\bnetserver.conf.dist\"," ^
  "  \"$b\start_mysql.bat\"" ^
  "); $existing = $files | Where-Object { Test-Path $_ };" ^
  "Compress-Archive -Path $existing -DestinationPath '%OUT_ZIP%' -Force"

if exist "%OUT_ZIP%" (
    for %%F in ("%OUT_ZIP%") do set /a SIZE_MB=%%~zF / 1048576
    echo [OK] server_binaries.zip created (!SIZE_MB! MB)
) else (
    echo [!] Failed to create server_binaries.zip. Check the BIN_SRC path above.
    pause & exit /b 1
)

:: ---- Package databases ----
echo.
echo [*] Creating databases.zip from ADB SQL files...
if not exist "%ADB_SRC%\ADB_735.10_world.sql" (
    echo [!] ADB SQL files not found at: %ADB_SRC%
    echo     Expected: %ADB_SRC%\ADB_735.10_world.sql
    echo     Download and extract ADB_735.10.rar first, then re-run.
    pause & exit /b 1
)
powershell -Command ^
  "Compress-Archive -Path '%ADB_SRC%\ADB_735.10_world.sql','%ADB_SRC%\ADB_735.10_hotfix.sql'" ^
  " -DestinationPath '%OUT_DB_ZIP%' -Force"

if exist "%OUT_DB_ZIP%" (
    for %%F in ("%OUT_DB_ZIP%") do set /a DB_MB=%%~zF / 1048576
    echo [OK] databases.zip created (!DB_MB! MB)
) else (
    echo [!] Failed to create databases.zip
    pause & exit /b 1
)

echo.
echo  =========================================================
echo   RELEASE ASSETS READY
echo  =========================================================
echo   Upload BOTH files as Release assets on GitHub:
echo   1. Go to your repo on GitHub
echo   2. Releases ^> Draft a new release
echo   3. Set tag: %RELEASE_TAG%
echo   4. Attach server_binaries.zip
echo   5. Attach databases.zip
echo   6. Publish release
echo.
echo   Files created:
echo     %OUT_ZIP%
echo     %OUT_DB_ZIP%
echo  =========================================================
echo.
pause
endlocal
