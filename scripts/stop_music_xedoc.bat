@echo off
setlocal
title stop music.xedoc.ru local inference

echo Stopping music.xedoc.ru tunnel and local backend...

taskkill /F /T /FI "WINDOWTITLE eq music.xedoc.ru Tunnel*" >nul 2>nul
taskkill /F /T /FI "WINDOWTITLE eq music.xedoc.ru Backend*" >nul 2>nul

powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'ssh.exe' -and $_.CommandLine -match '-R 8610:127\\.0\\.0\\.1:8610' -and $_.CommandLine -match '82\\.146\\.42\\.213' } | ForEach-Object { & taskkill.exe /F /T /PID $_.ProcessId *> $null }"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$conns = @(Get-NetTCPConnection -LocalPort 8610 -State Listen -ErrorAction SilentlyContinue); foreach ($conn in $conns) { if ($conn.OwningProcess) { & taskkill.exe /F /T /PID $conn.OwningProcess *> $null } }"

echo Done.
pause
endlocal
exit /b 0
