@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

cls

echo ======================================
echo        STEAM CLEANER TOOL
echo ======================================
echo.

echo ______
echo ^| ___ \
echo ^| ^|_/ /_   _ _ __ __ _  ___ _ __
echo ^| ___ \ ^| ^| ^| '__/ _` ^|/ _ \ '__^|
echo ^| ^|_/ / ^|_^| ^| ^| ^| (_^| ^|  __/ ^|
echo \____/ \__,_^|_^|  \__, ^|\___^|_^|
echo                   __/ ^|
echo                  ^|___/
echo.

timeout /t 1 >nul

call :step "Initialisation systeme..."
call :wait 1

call :step "Recherche de Steam..."

set "STEAMEXE="

for /f "tokens=2*" %%A in ('reg query "HKCU\Software\Valve\Steam" /v SteamPath 2^>nul ^| find "SteamPath"') do set "STEAMPATH=%%B"
if defined STEAMPATH set "STEAMPATH=%STEAMPATH:"=%"

if exist "%STEAMPATH%\steam.exe" set "STEAMEXE=%STEAMPATH%\steam.exe"
if exist "%STEAMPATH%\Steam.exe" set "STEAMEXE=%STEAMPATH%\Steam.exe"

if not defined STEAMEXE (
    if exist "C:\Program Files (x86)\Steam\steam.exe" set "STEAMEXE=C:\Program Files (x86)\Steam\steam.exe"
)

if not defined STEAMEXE (
    if exist "C:\Program Files\Steam\steam.exe" set "STEAMEXE=C:\Program Files\Steam\steam.exe"
)

if not defined STEAMEXE (
    call :step "ERREUR: Steam introuvable"
    timeout /t 3 >nul
    exit /b
)

call :step "Steam detecte"
call :wait 1

call :step "Fermeture de Steam..."
taskkill /IM steam.exe /F >nul 2>&1
call :wait 1

call :step "Nettoyage du cache..."

set "CACHEFILE=%STEAMEXE%\..\appcache\appinfo.vdf"
if exist "%CACHEFILE%" del /f /q "%CACHEFILE%" >nul 2>&1

call :wait 1

call :step "Redemarrage de Steam..."
start "" "%STEAMEXE%"
call :wait 1

call :step "Termine avec succes"

echo.
echo ======================================
echo OPERATION COMPLETE
echo Fermeture automatique...
echo ======================================

timeout /t 3 >nul

:: 🔥 AUTO-SUPPRESSION FIABLE
set "SELF=%~f0"
set "TMP=%temp%\steamcleaner_delete.bat"

echo @echo off > "%TMP%"
echo timeout /t 2 >nul >> "%TMP%"
echo del /f /q "%SELF%" >> "%TMP%"
echo del /f /q "%%~f0" >> "%TMP%"

start "" "%TMP%"
exit


:: =========================
:: STEP AVEC ASCII + BARRE
:: =========================
:step
set "msg=%~1"

for /L %%P in (0,25,100) do (
    set /a bars=%%P/4
    set /a spaces=25-bars

    set "bar="
    for /L %%A in (1,1,!bars!) do set "bar=!bar!█"
    for /L %%A in (1,1,!spaces!) do set "bar=!bar! "

    cls
    echo ======================================
    echo        STEAM CLEANER TOOL
    echo ======================================
    echo.
    echo ______
    echo ^| ___ \
    echo ^| ^|_/ /_   _ _ __ __ _  ___ _ __
    echo ^| ___ \ ^| ^| ^| '__/ _` ^|/ _ \ '__^|
    echo ^| ^|_/ / ^|_^| ^| ^| ^| (_^| ^|  __/ ^|
    echo \____/ \__,_^|_^|  \__, ^|\___^|_^|
    echo                   __/ ^|
    echo                  ^|___/
    echo.
    echo !msg!
    echo.
    echo [!bar!] %%P%%
    timeout /t 0 >nul
)

exit /b


:: =========================
:: WAIT
:: =========================
:wait
timeout /t %1 >nul
exit /b
