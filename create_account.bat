@echo off
setlocal EnableDelayedExpansion
title Create WoW Account

set "MYSQL=C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"
if not exist "%MYSQL%" set "MYSQL=C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"

echo.
echo  =========================================================
echo   Create a New WoW Account
echo  =========================================================
echo.
set /p "MYSQL_PASS=  MySQL root password (press Enter if none): "
set /p "ACCT_USER=  New account username: "
set /p "ACCT_PASS=  New account password: "
set /p "ACCT_EMAIL=  Account email (e.g. player@local.com): "
set /p "GM_LEVEL=  GM level (0=player, 1=moderator, 3=admin) [0]: "
if "!GM_LEVEL!"=="" set GM_LEVEL=0

:: Register account in auth DB
"%MYSQL%" -u root --password=!MYSQL_PASS! auth -e "INSERT IGNORE INTO account (username, salt, verifier, email, joindate) VALUES (UPPER('!ACCT_USER!'), '', '', '!ACCT_EMAIL!', NOW());" 2>&1

:: If GM, also set gmflags
if "!GM_LEVEL!" neq "0" (
    "%MYSQL%" -u root --password=!MYSQL_PASS! auth -e "INSERT IGNORE INTO account_access (id, gmlevel, RealmID) SELECT id, !GM_LEVEL!, -1 FROM account WHERE username = UPPER('!ACCT_USER!');" 2>&1
)

echo.
echo  =========================================================
echo   Account pre-created in auth DB.
echo   IMPORTANT: To finalize the password you must run the
echo   following commands IN the worldserver console window:
echo.
echo     account create !ACCT_USER! !ACCT_PASS!
echo     bnetaccount create !ACCT_EMAIL! !ACCT_PASS!
echo     bnetaccount link !ACCT_EMAIL! !ACCT_USER!
echo.
echo   Then log in with:  !ACCT_USER! / !ACCT_PASS!
echo  =========================================================
echo.
pause
endlocal
