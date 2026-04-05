@echo off
setlocal EnableDelayedExpansion
title WoW Legion 7.3.5 - Private Server

:: ============================================================
::  PLAY.BAT  —  Everything you need after first-time setup
::  Run this to: start the server, launch the game,
::               create accounts, or stop the server.
:: ============================================================

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "BIN=%ROOT%\server"
set "SQL_DIR=%ROOT%\sql"
set "LOG_DIR=%ROOT%\logs"
set "CLIENT="

set "MYSQL=C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"
if not exist "%MYSQL%" set "MYSQL=C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"

:: ---- Set up log file ----
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
for /f "tokens=1-3 delims=/ " %%a in ("%date%") do set "LOGDATE=%%c-%%a-%%b"
for /f "tokens=1-2 delims=: " %%a in ("%time: =0%") do set "LOGTIME=%%a%%b"
set "LOGFILE=%LOG_DIR%\play_%LOGDATE%_%LOGTIME%.log"

:: Logging helper — writes to screen AND log file
call :LOG "========================================"
call :LOG "play.bat started"
call :LOG "ROOT     : %ROOT%"
call :LOG "BIN      : %BIN%"
call :LOG "SQL_DIR  : %SQL_DIR%"
call :LOG "MYSQL    : %MYSQL%"
call :LOG "========================================"

:: ============================================================
::  CLIENT DISCOVERY
::  1. client_path.txt  (saved from a previous run)
::  2. WoW_Client\      (standard location inside repo)
::  3. Scan parent folder for known exe names
:: ============================================================

:: 1. Saved path
if exist "%ROOT%\client_path.txt" (
    set /p SAVED_CLIENT=<"%ROOT%\client_path.txt"
    if exist "!SAVED_CLIENT!" (
        set "CLIENT=!SAVED_CLIENT!"
        call :LOG "Client found via client_path.txt: !CLIENT!"
        goto :CLIENT_FOUND
    ) else (
        call :LOG "client_path.txt exists but path invalid: !SAVED_CLIENT!"
    )
)

:: 2. Standard subfolder
for %%E in (Wow.exe Wow-64.exe Hellgarve.Legion-64.exe) do (
    if exist "%ROOT%\WoW_Client\%%E" (
        set "CLIENT=%ROOT%\WoW_Client\%%E"
        call :LOG "Client found in WoW_Client\: %%E"
        goto :CLIENT_FOUND
    )
)

:: 3. Parent folder scan
set "PARENT=%ROOT%\.."
for /r "%PARENT%" %%F in (Wow.exe Wow-64.exe Hellgarve.Legion-64.exe) do (
    if exist "%%F" (
        set "CLIENT=%%F"
        call :LOG "Client found by scan: %%F"
        goto :CLIENT_FOUND
    )
)

call :LOG "Client not found - skipping auto-launch"

:CLIENT_FOUND

color 0A
cls
echo.
echo  =========================================================
echo   WoW Legion 7.3.5  --  Private Server
echo  =========================================================
echo.
echo   [1]  Play  (start server + launch game)
echo   [2]  Create a new account
echo   [3]  Stop the server
echo   [4]  Exit
echo.
set /p "CHOICE=  Choose an option: "
call :LOG "User selected: !CHOICE!"

if "!CHOICE!"=="1" goto :PLAY
if "!CHOICE!"=="2" goto :CREATE_ACCOUNT
if "!CHOICE!"=="3" goto :STOP
if "!CHOICE!"=="4" exit /b 0
echo  [!] Invalid choice.
pause & goto :eof

:: =====================================================
:PLAY
cls
call :LOG "--- PLAY ---"

:: ---- Sanity checks ----
call :LOG "Checking client: %CLIENT%"
if not exist "%CLIENT%" (
    call :LOG "ERROR: client exe not found"
    echo.
    echo  [!] WoW client not found at: %CLIENT%
    echo      Check client_path.txt or place client in WoW_Client\
    echo.
    echo  Log: %LOGFILE%
    pause & exit /b 1
)

call :LOG "Checking server: %BIN%\worldserver.exe"
if not exist "%BIN%\worldserver.exe" (
    call :LOG "ERROR: worldserver.exe not found"
    echo.
    echo  [!] Server not set up. Run SETUP.bat first.
    echo.
    echo  Log: %LOGFILE%
    pause & exit /b 1
)

call :LOG "Checking server binaries..."
for %%F in (bnetserver.exe libmysql.dll libcrypto-3-x64.dll libssl-3-x64.dll) do (
    if not exist "%BIN%\%%F" call :LOG "WARNING: missing %%F"
)


:: ---- Start MySQL ----
call :LOG "Checking MySQL..."
echo.
echo  [*] Checking MySQL...
tasklist /FI "IMAGENAME eq mysqld.exe" 2>NUL | find /I "mysqld.exe" >NUL
if errorlevel 1 (
    call :LOG "MySQL not running - attempting net start..."
    echo  [*] MySQL not running - starting...
    net start MySQL84 >nul 2>&1
    if not errorlevel 1 (
        call :LOG "MySQL84 service started OK"
    ) else (
        net start MySQL80 >nul 2>&1
        if not errorlevel 1 (
            call :LOG "MySQL80 service started OK"
        ) else (
            if exist "%BIN%\start_mysql.bat" (
                call :LOG "Trying start_mysql.bat fallback..."
                call "%BIN%\start_mysql.bat"
            ) else (
                call :LOG "ERROR: Cannot start MySQL"
                echo  [!] Could not start MySQL automatically.
                echo      Start MySQL from Windows Services, then re-run play.bat.
                echo.
                echo  Log: %LOGFILE%
                pause & exit /b 1
            )
        )
    )
    :: Wait up to 30 seconds for mysqld to be ready (port 3306 accepting connections)
    set /a MYSQL_WAIT=0
    :MYSQL_WAIT_LOOP
    netstat -ano 2>NUL | find ":3306" | find "LISTENING" >NUL
    if not errorlevel 1 goto :MYSQL_READY
    if !MYSQL_WAIT! GEQ 30 (
        call :LOG "ERROR: MySQL did not start in time"
        echo  [!] MySQL is not responding on port 3306 after 30 seconds.
        echo      Try starting MySQL manually from services.msc, then re-run play.bat.
        pause & exit /b 1
    )
    set /a MYSQL_WAIT+=2
    timeout /t 2 /nobreak >nul
    goto :MYSQL_WAIT_LOOP
    :MYSQL_READY
    call :LOG "MySQL ready on port 3306 (waited !MYSQL_WAIT!s)"
    echo  [OK] MySQL ready.
) else (
    call :LOG "MySQL already running"
    echo  [OK] MySQL already running.
)

:: ---- Read MySQL password from worldserver.conf ----
set "MYSQL_PASS="
if exist "%BIN%\worldserver.conf" (
    for /f "tokens=2 delims=;" %%A in ('findstr /i "LoginDatabaseInfo" "%BIN%\worldserver.conf" 2^>nul') do (
        rem LoginDatabaseInfo = "host;port;user;pass;db" - pass is 4th semicolon field
    )
    for /f "tokens=4 delims=;" %%P in ('findstr /i "^LoginDatabaseInfo" "%BIN%\worldserver.conf" 2^>nul') do (
        set "MYSQL_PASS=%%P"
        set "MYSQL_PASS=!MYSQL_PASS:"=!"
    )
)

:: ---- Apply instance data fix ----
call :LOG "Applying instance data fix..."
if exist "%MYSQL%" (
    if "!MYSQL_PASS!"=="" (
        "%MYSQL%" -u root characters < "%SQL_DIR%\04_fix_instance_data.sql" >nul 2>&1
    ) else (
        "%MYSQL%" -u root --password="!MYSQL_PASS!" characters < "%SQL_DIR%\04_fix_instance_data.sql" >nul 2>&1
    )
    call :LOG "Instance data fix applied (exit: %errorlevel%)"
)

:: ---- Kill stale processes ----
call :LOG "Killing stale bnetserver/worldserver if running..."
taskkill /F /IM bnetserver.exe /T >nul 2>&1
taskkill /F /IM worldserver.exe /T >nul 2>&1
timeout /t 2 /nobreak >nul

:: ---- Start bnetserver ----
call :LOG "Starting bnetserver from %BIN%..."
echo  [*] Starting bnetserver...
start "BNet Server" /D "%BIN%" cmd.exe /K ""%BIN%\bnetserver.exe""
timeout /t 4 /nobreak >nul

:: Verify bnetserver started
tasklist /FI "IMAGENAME eq bnetserver.exe" 2>NUL | find /I "bnetserver.exe" >NUL
if errorlevel 1 (
    call :LOG "WARNING: bnetserver.exe not seen in process list after start"
    echo  [!] WARNING: bnetserver may not have started. Check the BNet Server window.
) else (
    call :LOG "bnetserver.exe confirmed running"
    echo  [OK] bnetserver running.
)

:: ---- Start worldserver ----
call :LOG "Starting worldserver from %BIN%..."
echo  [*] Starting worldserver...
start "World Server" /D "%BIN%" cmd.exe /K ""%BIN%\worldserver.exe""

:: Brief pause to let worldserver.exe appear in process list before we start polling
timeout /t 5 /nobreak >nul

:: ---- Wait for load ----
echo.
echo  [*] Waiting for world server to finish loading...
echo      This can take 5-15 minutes on first run.
echo      Watch the "World Server" window - it will stop scrolling when ready.
echo.

set /a ELAPSED=0
:WAIT_LOOP
:: Check worldserver is still alive
tasklist /FI "IMAGENAME eq worldserver.exe" 2>NUL | find /I "worldserver.exe" >NUL
if errorlevel 1 (
    call :LOG "ERROR: worldserver.exe crashed during load"
    echo  [!] worldserver crashed while loading.
    echo      Check the "World Server" window for the error message.
    echo.
    pause & goto :eof
)
:: Check if port 8085 is open (worldserver ready to accept connections)
netstat -ano 2>NUL | find ":8085" | find "LISTENING" >NUL
if not errorlevel 1 (
    call :LOG "Port 8085 is LISTENING - worldserver ready after !ELAPSED!s"
    echo  [OK] World server is ready! ^(!ELAPSED! seconds^)
    goto :LAUNCH_CLIENT
)
set /a ELAPSED+=5
echo      Still loading... ^(!ELAPSED!s elapsed^)
timeout /t 5 /nobreak >nul
goto :WAIT_LOOP

:LAUNCH_CLIENT
:: Check worldserver is still alive before launching WoW
tasklist /FI "IMAGENAME eq worldserver.exe" 2>NUL | find /I "worldserver.exe" >NUL
if errorlevel 1 (
    call :LOG "ERROR: worldserver.exe crashed or exited before client launch"
    echo.
    echo  [!] worldserver appears to have stopped.
    echo      Check the "World Server" window for error messages.
    echo      Common causes:
    echo        - Missing data\ folder (run setup.bat)
    echo        - MySQL password changed (re-run setup.bat)
    echo        - Port 8085 or 1119 already in use
    echo.
    echo  Log: %LOGFILE%
    pause & goto :eof
)

call :LOG "Server ready - waiting for manual client launch"
echo.
echo  =========================================================
echo   Start Client to Proceed with Gameplay
echo   Server is running.  Choose option [3] to stop cleanly.
echo   Log: %LOGFILE%
echo  =========================================================
echo.
pause
goto :eof

:: =====================================================
:CREATE_ACCOUNT
cls
call :LOG "--- CREATE ACCOUNT ---"
echo.
echo  =========================================================
echo   Create a New WoW Account
echo  =========================================================
echo.

if not exist "%MYSQL%" (
    call :LOG "ERROR: mysql.exe not found at %MYSQL%"
    echo  [!] MySQL not found. Cannot create account automatically.
    pause & goto :eof
)

set /p "MYSQL_PASS=  MySQL root password (Enter for none): "
set /p "ACCT_USER=  Account username: "
set /p "ACCT_PASS=  Account password: "
set /p "ACCT_EMAIL=  Account email (e.g. player@local.com): "
set /p "GM_LEVEL=  GM level? (0=player, 3=admin) [0]: "
if "!GM_LEVEL!"=="" set GM_LEVEL=0

call :LOG "Creating account: !ACCT_USER! (GM: !GM_LEVEL!)"
"%MYSQL%" -u root --password=!MYSQL_PASS! auth -e ^
  "INSERT IGNORE INTO account (username, salt, verifier, email, joindate) VALUES (UPPER('!ACCT_USER!'), '', '', '!ACCT_EMAIL!', NOW());" 2>&1
call :LOG "Account insert done (exit: %errorlevel%)"

if "!GM_LEVEL!" neq "0" (
    "%MYSQL%" -u root --password=!MYSQL_PASS! auth -e ^
      "INSERT IGNORE INTO account_access (id, gmlevel, RealmID) SELECT id, !GM_LEVEL!, -1 FROM account WHERE username = UPPER('!ACCT_USER!');" 2>&1
    call :LOG "GM access set"
)

echo.
echo  [OK] Account registered in database.
echo.
echo  Now type these commands IN the worldserver console window to finalize:
echo.
echo    account create !ACCT_USER! !ACCT_PASS!
echo    bnetaccount create !ACCT_EMAIL! !ACCT_PASS!
echo    bnetaccount link !ACCT_EMAIL! !ACCT_USER!
echo.
pause
goto :eof

:: =====================================================
:STOP
call :LOG "--- STOP ---"
echo.
echo  [*] Stopping server...
taskkill /F /IM worldserver.exe >nul 2>&1
if not errorlevel 1 ( call :LOG "worldserver stopped" & echo  [OK] worldserver stopped. ) else ( echo  [--] worldserver was not running. )
taskkill /F /IM bnetserver.exe  >nul 2>&1
if not errorlevel 1 ( call :LOG "bnetserver stopped"  & echo  [OK] bnetserver stopped.  ) else ( echo  [--] bnetserver was not running. )
call :LOG "Stop complete"
echo.
echo  Done. Log: %LOGFILE%
pause
endlocal
goto :eof

:: =====================================================
:LOG
set "_MSG=%~1"
echo [%time%] %_MSG%>>"%LOGFILE%"
goto :eof
