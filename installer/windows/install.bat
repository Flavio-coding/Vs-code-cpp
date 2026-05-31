@echo off
:: VS Code C/C++ IDE — Launcher per l'installer PowerShell
:: Doppio clic su questo file per installare.

title VS Code C/C++ IDE - Installazione

echo.
echo  ======================================================
echo   VS Code C/C++ IDE - Installazione
echo  ======================================================
echo.
echo  Avvio del programma di installazione...
echo.

:: Check PowerShell
where powershell >nul 2>&1
if %errorlevel% neq 0 (
    echo  ERRORE: PowerShell non trovato.
    echo  Installa PowerShell da https://microsoft.com/powershell
    pause
    exit /b 1
)

:: Run the PowerShell installer with elevated execution policy for this session only
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"

if %errorlevel% neq 0 (
    echo.
    echo  ERRORE: Installazione fallita. Controlla i messaggi sopra.
    pause
    exit /b 1
)

pause
