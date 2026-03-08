@echo off
setlocal EnableDelayedExpansion
:: ============================================================
::  FOR REPO OWNER USE ONLY
::  Run this to package the server binaries into a zip
::  that you then upload as a GitHub Release asset.
:: ============================================================

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "BIN_SRC=C:\Users\donav\Desktop\Legion+repack+privateServer\AshamaneCore-master\bin"
set "OUT_ZIP=%ROOT%\server_binaries.zip"

echo [*] Creating server_binaries.zip from %BIN_SRC% ...

:: Build zip via PowerShell (inline array - no escaping issues)
powershell -Command "$b='%BIN_SRC%'; $f=@('$b\worldserver.exe','$b\bnetserver.exe','$b\connection_patcher.exe','$b\mapextractor.exe','$b\vmap4extractor.exe','$b\vmap4assembler.exe','$b\mmaps_generator.exe','$b\libcrypto-3-x64.dll','$b\libmysql.dll','$b\libssl-3-x64.dll','$b\bnetserver.cert.pem','$b\bnetserver.key.pem','$b\worldserver.conf.dist','$b\bnetserver.conf.dist'); $f=$f|ForEach-Object{$_-replace'\$b','%BIN_SRC%'}; Compress-Archive -Path $f -DestinationPath '%OUT_ZIP%' -Force"

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
    echo     Download and extract ADB_735.10.rar first, then re-run.
    pause & exit /b 1
)
powershell -Command "$f=@('%ADB_SRC%\ADB_735.10_world.sql','%ADB_SRC%\ADB_735.10_hotfix.sql'); Compress-Archive -Path $f -DestinationPath '%OUT_DB_ZIP%' -Force"
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
