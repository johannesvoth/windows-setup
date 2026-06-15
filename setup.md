# Windows Setup

## 1. Disable Watermark

```cmd
schtasks /create /tn "DisableWatermarkService" /tr "cmd.exe /c reg add HKLM\SYSTEM\CurrentControlSet\Services\svsvc /v Start /t REG_DWORD /d 4 /f" /sc ONSTART /ru SYSTEM
```

## 2. Background Image

Run in PowerShell:

```powershell
# 1. Define the content of the wallpaper script
$scriptContent = @'
$imgPath = "$env:USERPROFILE\Documents\pixel_wallpaper.png"

if (-not (Test-Path $imgPath)) {
    $imgPath = "$env:USERPROFILE\OneDrive\Documents\pixel_wallpaper.png"
}

$setwallpapersrc = @"
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet=CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@

if (Test-Path $imgPath) {
    Add-Type -TypeDefinition $setwallpapersrc
    [Wallpaper]::SystemParametersInfo(20, 0, $imgPath, 3)
}
'@

# 2. Save the script directly into your Documents folder
$scriptPath = "$env:USERPROFILE\Documents\SetWallpaper.ps1"
$scriptContent | Out-File -FilePath $scriptPath -Force
Write-Host "Wallpaper script saved to: $scriptPath" -ForegroundColor Green

# 3. Define the Task Scheduler action, trigger, and power settings
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

# 4. Register the task under your current user account
Register-ScheduledTask -TaskName "SetWallpaperOnLogon" -Action $action -Trigger $trigger -Settings $settings -Force
Write-Host "Scheduled task 'SetWallpaperOnLogon' successfully created!" -ForegroundColor Green
```

## Undo

Run in PowerShell to remove the scheduled tasks, wallpaper script, and restore the watermark service. Admin rights are required for the watermark changes.

```powershell
$ErrorActionPreference = 'Stop'

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Remove-TaskIfExists {
    param(
        [string]$TaskName,
        [switch]$SystemTask
    )

    if ($SystemTask) {
        schtasks /query /tn $TaskName 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            schtasks /delete /tn $TaskName /f | Out-Null
            Write-Host "Removed scheduled task: $TaskName" -ForegroundColor Green
            return
        }
    }
    elseif (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "Removed scheduled task: $TaskName" -ForegroundColor Green
        return
    }

    Write-Host "Scheduled task not found: $TaskName" -ForegroundColor Yellow
}

Write-Host "Undoing Windows setup changes..." -ForegroundColor Cyan

Remove-TaskIfExists -TaskName 'SetWallpaperOnLogon'

$scriptPath = Join-Path $env:USERPROFILE 'Documents\SetWallpaper.ps1'
if (Test-Path $scriptPath) {
    Remove-Item -Path $scriptPath -Force
    Write-Host "Removed wallpaper script: $scriptPath" -ForegroundColor Green
}
else {
    Write-Host "Wallpaper script not found: $scriptPath" -ForegroundColor Yellow
}

if (-not (Test-IsAdmin)) {
    Write-Host ""
    Write-Host "Admin rights are required to undo the watermark changes." -ForegroundColor Yellow
    Write-Host "Re-run this block as Administrator to finish cleanup." -ForegroundColor Yellow
    exit 1
}

Remove-TaskIfExists -TaskName 'DisableWatermarkService' -SystemTask

$regPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\svsvc'
if (Test-Path $regPath) {
    Set-ItemProperty -Path $regPath -Name 'Start' -Value 3 -Type DWord
    Write-Host "Restored svsvc service start type to Manual (3)" -ForegroundColor Green
}
else {
    Write-Host "Registry key not found: $regPath" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Undo complete. Reboot to apply the watermark service change." -ForegroundColor Cyan
```

If you are not already running as Administrator, right-click PowerShell and choose **Run as administrator**, then paste and run the block above again to finish cleanup.

`undo.ps1` in this repo is the same script if you prefer running it from a clone.
