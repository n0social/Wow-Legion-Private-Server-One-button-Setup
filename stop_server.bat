@echo off
echo [*] Stopping WoW Legion private server...
taskkill /F /IM worldserver.exe >nul 2>&1 && echo  [OK] worldserver stopped. || echo  [--] worldserver was not running.
taskkill /F /IM bnetserver.exe  >nul 2>&1 && echo  [OK] bnetserver stopped.  || echo  [--] bnetserver was not running.
echo.
echo Done.
pause
