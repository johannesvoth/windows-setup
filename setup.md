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
Set-ExecutionPolicy Bypass -Scope Process -Force
.\undo.ps1
```

If you are not already running as Administrator, right-click PowerShell and choose **Run as administrator**, then run the commands above again to finish cleanup.
