-- Windows 文件右键菜单「使用 neovim 打开」的注册与注销。
-- 仅写当前用户注册表，不需要管理员权限；不影响文件关联和「打开方式」列表。

local M = {}
local busy = false

-- RegistryPath / ExecutablePath 是测试入口；菜单调用时省略，使用固定项和当前 Neovide 进程路径。
local powershell_command = "& {\n" .. [=[
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("register", "unregister")]
  [string]$Action,
  [int]$NvimProcessId = 0,
  [string]$RegistryPath = "Software\Classes\*\shell\Neovide",
  [string]$ExecutablePath = ""
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

try {
  if ($Action -eq "unregister") {
    [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($RegistryPath, $false)
    Write-Output "UNREGISTERED"
    exit 0
  }

  if ([string]::IsNullOrWhiteSpace($ExecutablePath)) {
    $nvimProcess = Get-CimInstance Win32_Process -Filter "ProcessId = $NvimProcessId"
    if ($null -eq $nvimProcess) {
      throw "无法查询当前 Neovim 进程。"
    }
    $neovideProcess = Get-Process -Id $nvimProcess.ParentProcessId -ErrorAction Stop
    $ExecutablePath = $neovideProcess.Path
  }

  if ([string]::IsNullOrWhiteSpace($ExecutablePath)) {
    throw "无法确定 neovide.exe 的路径。"
  }
  if ([System.IO.Path]::GetFileName($ExecutablePath) -ine "neovide.exe") {
    throw "父进程不是 neovide.exe，已取消注册。"
  }

  $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($RegistryPath)
  try {
    $key.SetValue("", "使用 neovim 打开")
    $key.SetValue("Icon", '"' + $ExecutablePath + '"')
    $commandKey = $key.CreateSubKey("command")
    try {
      $command = [string]::Format('"{0}" --reuse-instance "%1"', $ExecutablePath)
      $commandKey.SetValue("", $command)
    }
    finally {
      $commandKey.Dispose()
    }
  }
  finally {
    $key.Dispose()
  }

  Write-Output ("REGISTERED=" + $ExecutablePath)
}
catch {
  Write-Error $_.Exception.Message
  exit 1
}
]=] .. "\n}"

local function run(action)
  if busy then
    vim.notify("系统菜单操作正在进行，请稍候。", vim.log.levels.WARN)
    return
  end
  if vim.fn.has("win32") ~= 1 then
    vim.notify("系统右键菜单注册仅支持 Windows。", vim.log.levels.WARN)
    return
  end

  busy = true
  local args = {
    "powershell.exe",
    "-NoProfile",
    "-NonInteractive",
    "-Command",
    powershell_command,
    action,
    tostring((vim.uv or vim.loop).os_getpid()),
  }

  local ok, err = pcall(vim.system, args, { text = true }, function(result)
    vim.schedule(function()
      busy = false
      if result.code == 0 then
        local message = action == "register" and "已注册文件右键菜单「使用 neovim 打开」。"
          or "已注销文件右键菜单「使用 neovim 打开」。"
        vim.notify(message)
      else
        local detail = vim.trim(result.stderr or "")
        if detail == "" then
          detail = vim.trim(result.stdout or "")
        end
        vim.notify("系统菜单操作失败：" .. detail, vim.log.levels.ERROR)
      end
    end)
  end)

  if not ok then
    busy = false
    vim.notify("无法启动 PowerShell：" .. tostring(err), vim.log.levels.ERROR)
  end
end

function M.register()
  run("register")
end

function M.unregister()
  run("unregister")
end

-- 供无界面测试调用，不暴露为菜单命令。
function M._run_for_test(action, registry_path, executable_path, callback)
  local args = {
    "powershell.exe",
    "-NoProfile",
    "-NonInteractive",
    "-Command",
    powershell_command,
    action,
    "0",
    registry_path,
    executable_path,
  }
  vim.system(args, { text = true }, callback)
end

return M
