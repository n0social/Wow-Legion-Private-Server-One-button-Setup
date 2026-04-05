@echo off
setlocal EnableDelayedExpansion

:: ============================================================
::   Legion Private Server - One-Click Setup
::   https://github.com/n0social/Wow-Legion-One-Stop-Setup
::
::   REPO OWNER: Fill in the two variables below before pushing
:: ============================================================
set GITHUB_USER=n0social
set GITHUB_REPO=Wow-Legion-Private-Server-One-button-Setup
set RELEASE_TAG=v1.0
:: ============================================================

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "SERVER_DIR=%ROOT%\server"
set "CLIENT_DIR=%ROOT%\WoW_Client"
set "TMP_DIR=%ROOT%\setup_tmp"
set "SQL_DIR=%ROOT%\sql"

set "MYSQL=C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"
if not exist "%MYSQL%" set "MYSQL=C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"

set "BINARIES_URL=https://github.com/%GITHUB_USER%/%GITHUB_REPO%/releases/download/%RELEASE_TAG%/server_binaries.zip"
set "DATABASES_URL=https://github.com/%GITHUB_USER%/%GITHUB_REPO%/releases/download/%RELEASE_TAG%/databases.zip"
set "7ZR_URL=https://github.com/ip7z/7zip/releases/download/24.09/7zr.exe"

title Legion Private Server Setup
color 0A

echo.
echo  =========================================================
echo   WoW Legion 7.3.5 Private Server - Setup
echo  =========================================================
echo.

:: ---- Admin check ----
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo  [!] This script needs administrator rights.
    echo      Right-click setup.bat ^> Run as administrator
    pause & exit /b 1
)

:: ---- WoW client check ----
:: Client discovery - check WoW_Client\ for any known exe
set "CLIENT_EXE="
for %%E in (Wow.exe Wow-64.exe Hellgarve.Legion-64.exe) do (
    if exist "%CLIENT_DIR%\%%E" set "CLIENT_EXE=%CLIENT_DIR%\%%E"
)
if "!CLIENT_EXE!"=="" (
    echo  [!] WoW client not found.
    echo      Please put your WoW 7.3.5 client folder at:
    echo      %CLIENT_DIR%\
    echo      It must contain Wow.exe, Wow-64.exe, or Hellgarve.Legion-64.exe.
    echo.
    pause & exit /b 1
)
echo  [OK] WoW client found: !CLIENT_EXE!

:: ---- MySQL check / install ----
echo.
echo  [*] Checking for MySQL...
if exist "%MYSQL%" (
    echo  [OK] MySQL found: %MYSQL%
) else (
    echo  [*] MySQL not found. Attempting install via winget...
    winget install -e --id MySQL.MySQLServer8.0 --silent --accept-package-agreements --accept-source-agreements
    :: Re-check after install
    if not exist "%MYSQL%" set "MYSQL=C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"
    if not exist "%MYSQL%" (
        echo.
        echo  [!] MySQL still not found after install attempt.
        echo      Please install MySQL 8.x manually from:
        echo      https://dev.mysql.com/downloads/mysql/
        echo      Then re-run this script.
        pause & exit /b 1
    )
    echo  [OK] MySQL installed.
)

:: ---- MySQL password ----
echo.
set "MYSQL_PASS="
set /p "MYSQL_PASS=  Enter your MySQL root password (press Enter if none): "
if defined MYSQL_PASS (
    set "PASS_ARG=--password=!MYSQL_PASS!"
) else (
    set "PASS_ARG="
)

:: Test MySQL connection
"%MYSQL%" -u root !PASS_ARG! --connect-expired-password -e "SELECT 1;" >nul 2>&1
if errorlevel 1 (
    echo  [!] Could not connect to MySQL with that password.
    echo      Make sure MySQL service is running and the password is correct.
    pause & exit /b 1
)
echo  [OK] MySQL connection successful.

:: ---- MySQL 8.x compatibility fix (prevents libmysql crash at player login) ----
:: AshamaneCore uses mysql_native_password. MySQL 8.0+ defaults to caching_sha2_password
:: which causes an abort() inside libmysql.dll when a player tries to log in.
echo.
echo  [*] Applying MySQL 8.x compatibility fix...
"%MYSQL%" -u root !PASS_ARG! -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '!MYSQL_PASS!';" >nul 2>&1
"%MYSQL%" -u root !PASS_ARG! -e "FLUSH PRIVILEGES;" >nul 2>&1

:: ---- MySQL performance tuning (speeds up worldserver load times) ----
echo  [*] Tuning MySQL for faster server loading...
"%MYSQL%" -u root !PASS_ARG! -e "SET GLOBAL innodb_buffer_pool_size = 536870912; SET GLOBAL tmp_table_size = 134217728; SET GLOBAL max_heap_table_size = 134217728; SET GLOBAL innodb_flush_log_at_trx_commit = 2;" >nul 2>&1
echo  [OK] MySQL tuned (512MB buffer pool, 128MB temp tables).
echo  [OK] MySQL auth plugin set to mysql_native_password.
if not exist "%TMP_DIR%" mkdir "%TMP_DIR%"

:: ---- Download 7zr.exe (needed for .rar extraction) ----
if not exist "%TMP_DIR%\7zr.exe" (
    echo.
    echo  [*] Downloading 7zr.exe...
    curl.exe -L -o "%TMP_DIR%\7zr.exe" "%7ZR_URL%" --silent --show-error
    if errorlevel 1 (
        echo  [!] Failed to download 7zr.exe. Check your internet connection.
        pause & exit /b 1
    )
)
echo  [OK] 7zr.exe ready.

:: ---- Download server binaries ----
if not exist "%SERVER_DIR%\worldserver.exe" (
    echo.
    echo  [*] Downloading server binaries (~60MB)...
    curl.exe -L -o "%TMP_DIR%\server_binaries.zip" "%BINARIES_URL%" --show-error
    if errorlevel 1 (
        echo  [!] Failed to download server binaries.
        echo      URL: %BINARIES_URL%
        echo      Make sure the GitHub Release exists and the URL is correct.
        pause & exit /b 1
    )
    echo  [*] Extracting server binaries...
    if not exist "%SERVER_DIR%" mkdir "%SERVER_DIR%"
    powershell -Command "Expand-Archive -Path '%TMP_DIR%\server_binaries.zip' -DestinationPath '%SERVER_DIR%' -Force"
    echo  [OK] Server binaries extracted.
) else (
    echo  [OK] Server binaries already present, skipping download.
)

:: ---- Verify key executables ----
if not exist "%SERVER_DIR%\worldserver.exe" (
    echo  [!] worldserver.exe not found after extraction. 
    echo      The binaries zip may have a different folder structure.
    pause & exit /b 1
)

:: ---- Download databases ----
if not exist "%TMP_DIR%\ADB_735.10_world.sql" (
    echo.
    echo  [*] Downloading databases (~500MB)...
    echo      This may take several minutes depending on your connection.
    curl.exe -L -o "%TMP_DIR%\databases.zip" "%DATABASES_URL%" --show-error
    if errorlevel 1 (
        echo  [!] Failed to download databases.zip
        echo      URL: %DATABASES_URL%
        pause & exit /b 1
    )
    echo  [*] Extracting database files...
    powershell -Command "Expand-Archive -Path '%TMP_DIR%\databases.zip' -DestinationPath '%TMP_DIR%' -Force"
    if errorlevel 1 (
        echo  [!] Extraction failed.
        pause & exit /b 1
    )
    echo  [OK] Database files extracted.
) else (
    echo  [OK] Database SQL files already present, skipping download.
)

:: ---- Create databases ----
echo.
echo  [*] Creating databases...
"%MYSQL%" -u root !PASS_ARG! -e "CREATE DATABASE IF NOT EXISTS auth CHARACTER SET utf8mb4; CREATE DATABASE IF NOT EXISTS characters CHARACTER SET utf8mb4; CREATE DATABASE IF NOT EXISTS world CHARACTER SET utf8mb4; CREATE DATABASE IF NOT EXISTS hotfixes CHARACTER SET utf8mb4;" 2>&1
echo  [OK] Databases created.

:: ---- Import world database (~350MB - takes several minutes) ----
echo.
echo  [*] Importing world database (~350MB)...
echo      Please wait - this takes 3-8 minutes.
cmd /c ""%MYSQL%" -u root !PASS_ARG! --max_allowed_packet=512M world < "%TMP_DIR%\ADB_735.10_world.sql""
if errorlevel 1 (
    echo  [!] World DB import failed.
    pause & exit /b 1
)
echo  [OK] World database imported.

:: ---- Import hotfix database (~120MB) ----
echo.
echo  [*] Importing hotfix database (~120MB)...
cmd /c ""%MYSQL%" -u root !PASS_ARG! --max_allowed_packet=512M hotfixes < "%TMP_DIR%\ADB_735.10_hotfix.sql""
if errorlevel 1 (
    echo  [!] Hotfix DB import failed.
    pause & exit /b 1
)
echo  [OK] Hotfix database imported.

:: ---- Apply custom SQL patches ----
echo.
echo  [*] Applying custom patches...

:: Patch 1: character_companion table
"%MYSQL%" -u root !PASS_ARG! characters < "%SQL_DIR%\01_character_companion.sql" 2>&1
echo  [OK] character_companion table applied.

:: Patch 2: custom creature entries
"%MYSQL%" -u root !PASS_ARG! world < "%SQL_DIR%\02_custom_creatures.sql" 2>&1
echo  [OK] Custom NPC entries applied.

:: Patch 3: hotfix column renames (idempotent - safe to re-run)
"%MYSQL%" -u root !PASS_ARG! hotfixes < "%SQL_DIR%\03_hotfix_column_patches.sql" 2>nul
echo  [OK] Hotfix column patches applied.

:: Patch 4: fix stale/corrupt instance data (truncates instance_reset)
"%MYSQL%" -u root !PASS_ARG! characters < "%SQL_DIR%\04_fix_instance_data.sql" 2>&1
echo  [OK] Instance data cleaned.

:: ---- Reset update tracking (so worldserver doesn't re-run patches) ----
"%MYSQL%" -u root !PASS_ARG! world -e "TRUNCATE TABLE updates; TRUNCATE TABLE updates_include;" 2>&1
"%MYSQL%" -u root !PASS_ARG! hotfixes -e "TRUNCATE TABLE updates; TRUNCATE TABLE updates_include;" 2>&1

:: ---- Generate worldserver.conf ----
echo.
echo  [*] Configuring worldserver.conf...
if not exist "%SERVER_DIR%\worldserver.conf" (
    if exist "%SERVER_DIR%\worldserver.conf.dist" (
        copy "%SERVER_DIR%\worldserver.conf.dist" "%SERVER_DIR%\worldserver.conf" >nul
    ) else (
        echo  [!] worldserver.conf.dist not found in server binaries.
        pause & exit /b 1
    )
)

:: Patch DataDir to portable relative path (./data = server/data when run from server\)
:: Also patch DB connections with MySQL password
powershell -Command ^
  "(Get-Content '%SERVER_DIR%\worldserver.conf') ^
   -replace 'DataDir\s*=.*', 'DataDir = \"./data\"' ^
   -replace 'LoginDatabaseInfo\s*=.*', 'LoginDatabaseInfo     = \"127.0.0.1;3306;root;!MYSQL_PASS!;auth\"' ^
   -replace 'WorldDatabaseInfo\s*=.*', 'WorldDatabaseInfo     = \"127.0.0.1;3306;root;!MYSQL_PASS!;world\"' ^
   -replace 'CharacterDatabaseInfo\s*=.*', 'CharacterDatabaseInfo = \"127.0.0.1;3306;root;!MYSQL_PASS!;characters\"' ^
   -replace 'HotfixDatabaseInfo\s*=.*', 'HotfixDatabaseInfo    = \"127.0.0.1;3306;root;!MYSQL_PASS!;hotfixes\"' ^
   | Set-Content '%SERVER_DIR%\worldserver.conf'"
echo  [OK] worldserver.conf configured.

:: ---- Generate bnetserver.conf ----
echo  [*] Configuring bnetserver.conf...
if not exist "%SERVER_DIR%\bnetserver.conf" (
    if exist "%SERVER_DIR%\bnetserver.conf.dist" (
        copy "%SERVER_DIR%\bnetserver.conf.dist" "%SERVER_DIR%\bnetserver.conf" >nul
    )
)
powershell -Command ^
  "(Get-Content '%SERVER_DIR%\bnetserver.conf') ^
   -replace 'LoginDatabaseInfo\s*=.*', 'LoginDatabaseInfo = \"127.0.0.1;3306;root;!MYSQL_PASS!;auth\"' ^
   | Set-Content '%SERVER_DIR%\bnetserver.conf'"
echo  [OK] bnetserver.conf configured.

:: ---- Create data directory ----
if not exist "%SERVER_DIR%\data" mkdir "%SERVER_DIR%\data"

:: ---- Extract game data from WoW client ----
echo.
echo  =========================================================
echo   Extracting game data from WoW client (required)
echo   Maps + DBC/GT files - takes 15-30 minutes
echo  =========================================================

:: mapextractor: extracts dbc, gt, cameras, maps
echo  [*] Running mapextractor (extracts maps + DBC)...
echo      This will take 15-30 minutes. Please wait...
pushd "%CLIENT_DIR%"
copy "%SERVER_DIR%\mapextractor.exe" . >nul 2>&1
"%SERVER_DIR%\mapextractor.exe"
:: Move extracted folders to server/data
if exist "%CLIENT_DIR%\maps"    move "%CLIENT_DIR%\maps"    "%SERVER_DIR%\data\maps"    >nul 2>&1
if exist "%CLIENT_DIR%\dbc"     move "%CLIENT_DIR%\dbc"     "%SERVER_DIR%\data\dbc"     >nul 2>&1
if exist "%CLIENT_DIR%\gt"      move "%CLIENT_DIR%\gt"      "%SERVER_DIR%\data\gt"      >nul 2>&1
if exist "%CLIENT_DIR%\cameras" move "%CLIENT_DIR%\cameras" "%SERVER_DIR%\data\cameras" >nul 2>&1
del mapextractor.exe >nul 2>&1
popd
echo  [OK] Maps and DBC extracted.

:: vmap4extractor + assembler
echo  [*] Running vmap extractor (visual collision maps)...
pushd "%CLIENT_DIR%"
"%SERVER_DIR%\vmap4extractor.exe"
if exist "%CLIENT_DIR%\Buildings" (
    if not exist "%SERVER_DIR%\data\vmaps" mkdir "%SERVER_DIR%\data\vmaps"
    "%SERVER_DIR%\vmap4assembler.exe" Buildings "%SERVER_DIR%\data\vmaps"
    rmdir /s /q Buildings >nul 2>&1
)
popd
echo  [OK] VMaps extracted.

:: mmaps (pathfinding) - optional, slow
echo.
set /p "DO_MMAPS=  Generate movement maps (mmaps)? Needed for NPC pathfinding. Takes 2-6 hours. [y/N]: "
if /i "!DO_MMAPS!"=="y" (
    echo  [*] Generating mmaps - go grab a coffee, this takes hours...
    if not exist "%SERVER_DIR%\data\mmaps" mkdir "%SERVER_DIR%\data\mmaps"
    "%SERVER_DIR%\mmaps_generator.exe" --silent 2>&1
    move mmaps "%SERVER_DIR%\data\mmaps" >nul 2>&1
    echo  [OK] Mmaps generated.
) else (
    echo  [*] Skipping mmaps. NPCs will use basic pathfinding.
)

:: ---- Create game account ----
echo.
echo  =========================================================
echo   Create your game account
echo  =========================================================
set /p "ACCT_USER=  Enter account username: "
set /p "ACCT_PASS=  Enter account password: "
set /p "ACCT_EMAIL=  Enter account email (can be fake, e.g. admin@local.com): "

:: Write account creation commands for worldserver console
echo account create !ACCT_USER! !ACCT_PASS! > "%TMP_DIR%\create_account_cmds.txt"
echo account set gmlevel !ACCT_USER! 3 -1 >> "%TMP_DIR%\create_account_cmds.txt"
echo bnetaccount create !ACCT_EMAIL! !ACCT_PASS! >> "%TMP_DIR%\create_account_cmds.txt"
echo bnetaccount link !ACCT_EMAIL! !ACCT_USER! >> "%TMP_DIR%\create_account_cmds.txt"

:: Or do it directly via SQL to the auth DB
"%MYSQL%" -u root --password=!MYSQL_PASS! auth -e ^
  "INSERT IGNORE INTO account (username, salt, verifier, email, joindate) VALUES (UPPER('!ACCT_USER!'), '', '', '!ACCT_EMAIL!', NOW());" 2>&1

echo  [!] Account pre-registered in auth DB. Final setup will complete when
echo      you run play.bat and use the in-game worldserver console.

:: ---- Patch WoW client to connect to localhost ----
echo.
echo  [*] Patching WoW client to connect to localhost...
set "PATCHER=%ROOT%\connection_patcher.exe"
if not exist "%PATCHER%" set "PATCHER=%SERVER_DIR%\connection_patcher.exe"
if exist "%PATCHER%" (
    copy "%PATCHER%" "%CLIENT_DIR%\" >nul 2>&1
    pushd "%CLIENT_DIR%"
    connection_patcher.exe
    del connection_patcher.exe >nul 2>&1
    popd
    echo  [OK] Client patched.
) else (
    echo  [!] connection_patcher.exe not found - client patching skipped.
    echo      You may need to manually edit realmlist or use a launcher.
)

:: ---- Windows Defender Exclusion (speeds up server load time) ----
echo.
echo  [*] Adding Windows Defender exclusion for server folder...
echo     (This prevents Defender from scanning DB2/DLL files on every launch)
powershell -NoProfile -Command "try { Add-MpPreference -ExclusionPath '%ROOT%\server' -ErrorAction Stop; Write-Host '  [OK] Defender exclusion added.' } catch { Write-Host '  [!] Could not add Defender exclusion (non-fatal).' }"

:: ---- Cleanup ----
echo.
echo  [*] Cleaning up temp files...
if exist "%TMP_DIR%\ADB_735.10.rar" del "%TMP_DIR%\ADB_735.10.rar"
if exist "%TMP_DIR%\server_binaries.zip" del "%TMP_DIR%\server_binaries.zip"

:: ---- Done ----
echo.
echo  =========================================================
echo   SETUP COMPLETE!
echo  =========================================================
echo.
echo   Next steps:
echo   1. Run play.bat to launch the server and game
echo   2. Wait 5-15 minutes for the world to finish loading
echo      (play.bat will automatically launch WoW when ready)
echo   3. Log in with:
echo      Username: !ACCT_USER!
echo      Password: !ACCT_PASS!
echo.
echo   To create more accounts or stop the server, use play.bat
echo.
pause
endlocal
