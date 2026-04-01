@echo off
echo [*] Starting MySQL...

:: Try Windows service first (most reliable)
net start MySQL84 >nul 2>&1
if not errorlevel 1 (
    echo [OK] MySQL 8.4 service started.
    goto :mysql_ready
)

net start MySQL80 >nul 2>&1
if not errorlevel 1 (
    echo [OK] MySQL 8.0 service started.
    goto :mysql_ready
)

:: Fallback: launch mysqld.exe directly (for non-service installs)
set "MYSQLD84=C:\Program Files\MySQL\MySQL Server 8.4\bin\mysqld.exe"
set "MYSQLD80=C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqld.exe"
set "DATA84=C:\ProgramData\MySQL\MySQL Server 8.4\Data"
set "DATA80=C:\ProgramData\MySQL\MySQL Server 8.0\Data"

if exist "%MYSQLD84%" (
    start "" /min "%MYSQLD84%" --datadir="%DATA84%" --bind-address=127.0.0.1 --port=3306
    set "MYSQL_CLI=C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"
    goto :wait
)
if exist "%MYSQLD80%" (
    start "" /min "%MYSQLD80%" --datadir="%DATA80%" --bind-address=127.0.0.1 --port=3306
    set "MYSQL_CLI=C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"
    goto :wait
)

echo [!] MySQL not found. Install MySQL 8.x and re-run.
exit /b 1

:wait
echo [*] Waiting for MySQL to become ready...
timeout /t 8 /nobreak >nul

:mysql_ready
echo [OK] MySQL is ready.

