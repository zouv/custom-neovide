@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

rem ============================================================
rem  Neovide 文件关联注册脚本（双击运行）
rem  把本脚本放到 neovide.exe 同目录，会把「当前目录」的 neovide.exe
rem  注册为打开命令，并带上 --reuse-instance（双击文件复用已运行实例）。
rem  注册前会检测旧的关联命令，并提示是否替换。
rem ============================================================

set "EXE=%~dp0neovide.exe"

if not exist "%EXE%" (
  echo [错误] 脚本同目录未找到 neovide.exe
  echo        脚本目录: %~dp0
  echo        请把本脚本放到 neovide.exe 同目录再双击运行。
  pause
  exit /b 1
)

echo ============================================================
echo   Neovide 文件关联注册
echo ============================================================
echo   当前 exe : %EXE%
echo.

rem 读取旧的 open 命令（不存在则为空）
set "OLDCMD="
for /f "tokens=2,*" %%A in ('reg query "HKCU\Software\Classes\Applications\neovide.exe\shell\open\command" /ve 2^>nul') do set "OLDCMD=%%B"

if defined OLDCMD (
  echo   检测到旧关联:
  echo     !OLDCMD!
  echo.
  set /p CONFIRM=   是否替换成当前路径并注册? [Y/N]:
  if /i not "!CONFIRM!"=="Y" (
    echo   已取消，未做任何改动。
    pause
    exit /b 0
  )
) else (
  echo   未检测到旧关联，直接注册。
  echo.
)

rem 生成 .reg 并导入（引号与 %%1 交给 reg import 处理最稳）
set "REG_FILE=%TEMP%\neovide-assoc-%RANDOM%.reg"
> "%REG_FILE%" (
  echo Windows Registry Editor Version 5.00
  echo.
  echo [HKEY_CURRENT_USER\Software\Classes\Applications\neovide.exe\shell\open\command]
  echo @="\"%EXE%\" --reuse-instance \"%%1\""
)
reg import "%REG_FILE%" >nul
if errorlevel 1 (
  echo [错误] 注册失败（reg import）。
  del "%REG_FILE%" >nul 2>&1
  pause
  exit /b 1
)
del "%REG_FILE%" >nul 2>&1

echo.
echo   注册成功，当前命令:
reg query "HKCU\Software\Classes\Applications\neovide.exe\shell\open\command" /ve
echo.
echo   说明: 双击已关联的文件时，会复用正在运行的实例；
echo         没有实例运行时则正常启动新实例。
echo.
pause
