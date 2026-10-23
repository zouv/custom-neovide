@echo off
chcp 65001 >nul
setlocal

rem ============================================================
rem  neovide-custom - build unpacked (portable) package
rem  Output: dist\win-unpacked\neovide.exe
rem  Usage:
rem    build-unpacked.bat              cargo build --release + copy to dist
rem    build-unpacked.bat --skip-build  skip cargo build, re-copy existing exe
rem ============================================================

rem Project root: script lives at <repo>\CUSTOMIZATIONS\scripts\
set "ROOT=%~dp0..\.."
pushd "%ROOT%"

set "SKIP_BUILD="
if /I "%~1"=="--skip-build" (
  set "SKIP_BUILD=1"
  shift
)

echo ============================================================
echo  Build unpacked ^| project : %CD%
echo                     output : dist\win-unpacked\
echo ============================================================

where cargo >nul 2>&1
if errorlevel 1 goto :NoCargo

rem Kill resident instances so the output exe is not locked
echo Stopping any running Neovide instances...
taskkill /IM "neovide.exe" /F >nul 2>&1

if not "%SKIP_BUILD%"=="1" (
  echo.
  echo [1/2] cargo build --release ...
  rem 默认使用 skia 预编译二进制（动态 CRT）。如需静态链接 MSVC 运行库
  rem （免装 VC++ 运行库），需先安装 LLVM + ninja 并与 CI 一致，再取消下面这行注释：
  rem set "RUSTFLAGS=-Ctarget-feature=+crt-static"
  call cargo build --release
  if errorlevel 1 goto :BuildFailed
) else (
  echo.
  echo [1/2] Skipping build ^(--skip-build^).
)

echo.
echo [2/2] Copying neovide.exe to dist\win-unpacked\ ...
if not exist "dist\win-unpacked" mkdir "dist\win-unpacked"

rem Retry loop (chatbox CUSTOM-20260903-009 experience): antivirus scans the
rem freshly written exe and briefly locks it, so retry the copy with a backoff.
set "TRIES=0"
:CopyRun
copy /Y "target\release\neovide.exe" "dist\win-unpacked\neovide.exe" >nul 2>&1
if not errorlevel 1 goto :CopyDone
set /a TRIES+=1
if %TRIES% GEQ 3 goto :CopyFailed
echo [WARN] copy failed ^(try %TRIES%/3^). Antivirus may be scanning the output; waiting 15s before retry...
rem Absolute path, not bare `timeout`: when launched from Git Bash, PATH resolves
rem `timeout` to GNU coreutils' timeout, which rejects /t and returns immediately.
"%SystemRoot%\System32\timeout.exe" /t 15 /nobreak >nul 2>&1 || ping -n 16 127.0.0.1 >nul
goto :CopyRun
:CopyDone

echo.
echo ============================================================
echo  Output:
echo ============================================================
if exist "dist\win-unpacked\neovide.exe" (
  for %%F in ("dist\win-unpacked\neovide.exe") do (
    echo   portable : %%~fF
    echo   size     : %%~zF bytes
  )
) else (
  echo   [WARN] dist\win-unpacked\neovide.exe not found
)

echo.
echo [SUCCESS] unpacked build finished.
popd
exit /b 0

:NoCargo
echo [ERROR] cargo CLI not found. Install Rust first (https://rustup.rs).
popd
exit /b 1

:BuildFailed
echo.
echo [FAILED] cargo build --release failed.
popd
exit /b 1

:CopyFailed
echo.
echo [FAILED] copy to dist\win-unpacked failed after retries.
popd
exit /b 1
