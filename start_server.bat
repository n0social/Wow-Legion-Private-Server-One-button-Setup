@echo off
setlocal EnableDelayedExpansion
set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "SERVER_DIR=%ROOT%\server"

title WoW Legion Private Server

if not exist "%SERVER_DIR%\worldserver.exe" (
    echo [!] Server not found. Please run setup.bat first.
    pause & exit /b 1
)

echo [*] Starting bnetserver...
start "BNet Server" /D "%SERVER_DIR%" "%SERVER_DIR%\bnetserver.exe"

echo [*] Waiting 5 seconds before starting worldserver...
timeout /t 5 /nobreak >nul

echo [*] Starting worldserver...
start "World Server" /D "%SERVER_DIR%" "%SERVER_DIR%\worldserver.exe"

echo.
echo  Both servers are starting.
echo  Wait ~60 seconds for the world to finish loading, then launch Wow.exe
echo.
echo  -- Server windows are open in the taskbar --
echo  -- Close them or run stop_server.bat to shut down --
echo.
pause
endlocal
