@echo off
chcp 65001 >nul
setlocal

rem ============================================================
rem  neovide-custom - build MSI Setup installer
rem  Output: dist\neovide-<version>.msi
rem          version comes from Cargo.toml ([package].version)
rem  Usage:
rem    build-setup.bat              cargo wix (build + MSI) + copy to dist
rem    build-setup.bat --skip-build  skip cargo build, run cargo wix only
rem
rem  Requires: cargo-wix + WiX Toolset v3 (candle/light). cargo-wix is
rem  installed automatically if missing; WiX must be installed separately.
rem ============================================================

rem Project root: script lives at <repo>\CUSTOMIZATIONS\scripts\
set "ROOT=%~dp0..\.."
pushd "%ROOT%"

set "SKIP_BUILD="
if /I "%~1"=="--skip-build" (
  set "SKIP_BUILD=1"
  shift
)

rem Read version from Cargo.toml (first `version = "..."`, i.e. [package].version)
for /f "usebackq delims=" %%V in (`powershell -NoProfile -Command "(Select-String -Path 'Cargo.toml' -Pattern '^version = \"(.+)\"').Matches[0].Groups[1].Value"`) do set "APP_VERSION=%%V"
if "%APP_VERSION%"=="" (
  echo [ERROR] Could not read version from Cargo.toml.
  popd
  exit /b 1
)

echo ============================================================
echo  Build Setup  ^| project : %CD%
echo                version : %APP_VERSION%
echo                artifact: neovide-%APP_VERSION%.msi
echo                output  : dist\
echo ============================================================

where cargo >nul 2>&1
if errorlevel 1 goto :NoCargo

rem Ensure cargo-wix is available
cargo wix --version >nul 2>&1
if errorlevel 1 (
  echo [INFO] cargo-wix not found, installing via cargo install ...
  where cargo-binstall >nul 2>&1 && (
    cargo binstall -y cargo-wix
  ) || (
    cargo install cargo-wix --locked
  )
  if errorlevel 1 goto :NoCargoWix
)

rem Kill resident instances so the output msi/exe is not locked
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
echo [2/2] cargo wix ^(MSI^) ...
call cargo wix --nocapture --output target\release\neovide.msi --package neovide
if errorlevel 1 goto :WixFailed

echo.
echo [3/3] Copying neovide.msi to dist\ ...
if not exist "dist" mkdir "dist"

rem Retry loop for antivirus file lock (see build-unpacked.bat)
set "TRIES=0"
:CopyRun
copy /Y "target\release\neovide.msi" "dist\neovide-%APP_VERSION%.msi" >nul 2>&1
if not errorlevel 1 goto :CopyDone
set /a TRIES+=1
if %TRIES% GEQ 3 goto :CopyFailed
echo [WARN] copy failed ^(try %TRIES%/3^). Antivirus may be scanning the output; waiting 15s before retry...
"%SystemRoot%\System32\timeout.exe" /t 15 /nobreak >nul 2>&1 || ping -n 16 127.0.0.1 >nul
goto :CopyRun
:CopyDone

echo.
echo ============================================================
echo  Output:
echo ============================================================
set "FOUND_SETUP="
for %%F in ("dist\neovide-%APP_VERSION%.msi") do (
  echo   setup : %%~fF
  echo   size  : %%~zF bytes
  set "FOUND_SETUP=1"
)
if not defined FOUND_SETUP (
  echo   [WARN] dist\neovide-%APP_VERSION%.msi not found
  echo   listing dist\*.msi :
  dir /b "dist\*.msi" 2>nul
)

echo.
echo [SUCCESS] Setup build finished.
echo   Use the neovide-publish skill for a full GitHub release.
popd
exit /b 0

:NoCargo
echo [ERROR] cargo CLI not found. Install Rust first (https://rustup.rs).
popd
exit /b 1

:NoCargoWix
echo [ERROR] failed to install cargo-wix.
popd
exit /b 1

:BuildFailed
echo.
echo [FAILED] cargo build --release failed.
popd
exit /b 1

:WixFailed
echo.
echo [FAILED] cargo wix failed. Make sure WiX Toolset v3 (candle/light) is installed,
echo   or set WIX to the WiX bin directory.
popd
exit /b 1

:CopyFailed
echo.
echo [FAILED] copy to dist failed after retries.
popd
exit /b 1
