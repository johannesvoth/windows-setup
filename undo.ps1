#Requires -Version 5.1

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
    Write-Host "Re-run this script as Administrator to finish cleanup." -ForegroundColor Yellow
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
