@echo off
REM main.bat — Launcher Windows para main.ps1 (bootstrap da aplicacao).
REM Uso: main.bat decode -Uuid <uuid> [-DataFile <csv>] [-Quiet]
REM      main.bat batch  -InputFile <entrada> -OutputFile <saida.csv>
REM      main.bat help
setlocal
set "SCRIPT_DIR=%~dp0"
where pwsh >nul 2>nul
if %ERRORLEVEL%==0 (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%main.ps1" %*
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%main.ps1" %*
)
exit /b %ERRORLEVEL%
