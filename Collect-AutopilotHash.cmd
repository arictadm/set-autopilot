@echo off
REM Runs the Autopilot hash harvester from wherever this USB is plugged in.
REM At OOBE: press Shift+F10, then type the path to this file, e.g.  D:\Collect-AutopilotHash.cmd
echo.
echo Collecting Autopilot hardware hash from this device...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Get-AutopilotHash.ps1"
echo.
pause
