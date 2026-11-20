@echo off
setlocal
cd /d "%~dp0"
if not defined LIMINAL_GODOT_EXE set "LIMINAL_GODOT_EXE=%LOCALAPPDATA%\LiminalSkyStation\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
if not exist "%LIMINAL_GODOT_EXE%" (
  echo Set LIMINAL_GODOT_EXE to the path of Godot 4.7.2 and reopen this file.
  pause
  exit /b 1
)
if not exist ".godot\global_script_class_cache.cfg" (
  "%LIMINAL_GODOT_EXE%" --headless --editor --import --path "%CD%"
  if errorlevel 1 goto failed
)
start "" "%LIMINAL_GODOT_EXE%" --path "%CD%" --rendering-method forward_plus
exit /b 0

:failed
echo Godot could not import the station project.
pause
exit /b 1
