@echo off
REM Backup retention: delete Windows Server Backup sets older than 7 days
REM from the TrueNAS BackupSet03 share. Scheduled daily at 6:30 AM (Task Scheduler: delBackup).
setlocal
net use Z: \\44.38.3.50\BackupSet03 /persistent:no
forfiles /p "Z:\WindowsImageBackup" /m "Backup*" /d -7 /c "cmd /c rd /s /q @path"
net use Z: /delete /yes
endlocal
