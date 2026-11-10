@echo off
REM Rename the newest Windows Server Backup set with a timestamp so the next
REM backup doesn't overwrite it. Runs after each backup (Task Scheduler: renameBackup).
REM Date parsing assumes the US short-date format "Ddd MM/DD/YYYY".
setlocal
set "YY=%date:~-4%"
set "MM=%date:~4,2%"
set "DD=%date:~7,2%"
set "HH=%time:~0,2%"
set "MN=%time:~3,2%"
if "%HH:~0,1%"==" " set "HH=0%HH:~1,1%"
set "Stamp=%YY%-%MM%-%DD%_%HH%-%MN%"
ren "\\44.38.3.50\BackupSet03\WindowsImageBackup\G03SRV01VM" "Backup-%Stamp%"
endlocal
