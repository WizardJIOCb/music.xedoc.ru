@echo off
setlocal
title music.xedoc.ru local inference

set "APP_DIR=C:\pinokio\api\stabledaw.pinokio.git"
set "BACKEND_DIR=%APP_DIR%\app"
set "PYTHON_EXE=%BACKEND_DIR%\.venv\Scripts\python.exe"
set "BACKEND_PORT=8610"
set "SERVER=root@82.146.42.213"
set "PUBLIC_URL=https://music.xedoc.ru"

echo ========================================
echo   music.xedoc.ru local inference
echo ========================================
echo.

if not exist "%PYTHON_EXE%" (
  echo Python environment not found:
  echo   "%PYTHON_EXE%"
  echo Run StableDAW install locally first.
  pause
  exit /b 1
)

if not exist "%APP_DIR%\models\stable-audio-3-medium\stable-audio-3-medium-ARC.safetensors" (
  echo Medium ARC model is not found:
  echo   "%APP_DIR%\models\stable-audio-3-medium\stable-audio-3-medium-ARC.safetensors"
  pause
  exit /b 1
)

echo Checking local backend on port %BACKEND_PORT%...
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $m = Invoke-RestMethod -Uri 'http://127.0.0.1:%BACKEND_PORT%/api/model-info' -TimeoutSec 2; if ($m.active_model -eq 'medium') { exit 0 } } catch {}; exit 1" >nul 2>nul
if "%ERRORLEVEL%"=="0" goto backend_ready

echo Stopping stale process on port %BACKEND_PORT%, if any...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$conns = @(Get-NetTCPConnection -LocalPort %BACKEND_PORT% -State Listen -ErrorAction SilentlyContinue); foreach ($conn in $conns) { if ($conn.OwningProcess) { & taskkill.exe /F /T /PID $conn.OwningProcess *> $null } }" >nul 2>nul

echo Starting StableDAW backend with Medium ARC on port %BACKEND_PORT%...
start "music.xedoc.ru Backend %BACKEND_PORT%" cmd /k "cd /d %BACKEND_DIR% && set SA3_LOCAL_MODELS_DIR=%APP_DIR%\models&& set SA3_LOCAL_ONLY=1&& set STABLEDAW_DEFAULT_MODEL=medium&& set PYTHONPATH=%APP_DIR%&& %PYTHON_EXE% -m uvicorn server_wrapper:app --host 127.0.0.1 --port %BACKEND_PORT%"

echo Waiting for Medium ARC to load. This can take a few minutes...
for /l %%i in (1,1,360) do (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $m = Invoke-RestMethod -Uri 'http://127.0.0.1:%BACKEND_PORT%/api/model-info' -TimeoutSec 2; if ($m.active_model -eq 'medium') { exit 0 } } catch {}; exit 1" >nul 2>nul
  if not errorlevel 1 goto backend_ready
  timeout /t 2 /nobreak >nul
)

echo.
echo Backend did not report Medium ARC ready in time.
echo Check the backend console window for CUDA/VRAM errors.
pause
exit /b 1

:backend_ready
echo Backend is ready on http://127.0.0.1:%BACKEND_PORT%
echo Starting reverse SSH tunnel to %SERVER%...

taskkill /F /T /FI "WINDOWTITLE eq music.xedoc.ru Tunnel*" >nul 2>nul
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'ssh.exe' -and $_.CommandLine -match '-R 8610:127\\.0\\.0\\.1:8610' -and $_.CommandLine -match '82\\.146\\.42\\.213' } | ForEach-Object { & taskkill.exe /F /T /PID $_.ProcessId *> $null }" >nul 2>nul
start "music.xedoc.ru Tunnel" cmd /k "ssh -N -T -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -R 8610:127.0.0.1:%BACKEND_PORT% %SERVER%"

echo Waiting for public API through tunnel...
for /l %%i in (1,1,30) do (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $h = Invoke-RestMethod -Uri '%PUBLIC_URL%/api/health' -TimeoutSec 3; if ($h.model_loaded) { exit 0 } } catch {}; exit 1" >nul 2>nul
  if not errorlevel 1 goto public_ready
  timeout /t 2 /nobreak >nul
)

echo.
echo Tunnel window started, but public API is not ready yet.
echo Keep the tunnel window open and check:
echo   %PUBLIC_URL%/api/health
pause
exit /b 1

:public_ready
echo.
echo Public site is ready:
echo   %PUBLIC_URL%
echo.
start "" "%PUBLIC_URL%"
endlocal
exit /b 0
