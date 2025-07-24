$logFile = ".\UpdateServices.log"
$logerrFile = ".\UpdateServices.err"

# Sovrascrive il file di log (lo svuota all'avvio dello script)
"" | Out-File -FilePath $logFile -Encoding UTF8
"" | Out-File -FilePath $logerrFile -Encoding UTF8

function Write-Log {
    param (
        [string]$Message
    )
    # Scrivi solo su file
    $Message | Out-File -FilePath $logFile -Append -Encoding UTF8
}

function Write-LogError {
    param (
        [string]$Message
    )
    # Scrivi solo su file
    $Message | Out-File -FilePath $logerrFile -Append -Encoding UTF8
}

Import-Csv -Path .\ServiceList.csv | ForEach-Object {
    $changed = $false
    $service = Get-Service -Name $_.Service -ErrorAction SilentlyContinue

    if (-not $service) {
        $logMsg = "Service $($_.Service) not found."
        Write-Host $logMsg -ForegroundColor Red
        Write-Log $logMsg
        return
    }

    if ($service.StartType -ne $_.StartType) {
        Write-Host "Changing StartType for service $($service.Name)" -ForegroundColor Yellow
        try {
            $service | Set-Service -StartupType $_.StartType -ErrorAction Stop
            $changed = $true
        } catch {
            $logMsg = "Error changing StartType for $($service.Name): $_"
            Write-Host $logMsg -ForegroundColor Red
            Write-Log $logMsg
            Write-LogError $logMsg
       }
    }

    if ($service.Status -ne $_.Status) {
        Write-Host "Changing Status for service $($service.Name)" -ForegroundColor Yellow
        try {
            if ($_.Status -eq "Running") {
                Start-Service -Name $service.Name -ErrorAction Stop
            } elseif ($_.Status -eq "Stopped") {
                Stop-Service -Name $service.Name -ErrorAction Stop
            }
            $changed = $true
        } catch {
            $logMsg ="Error changing Status for $($service.Name): $_"
            Write-Host $logMsg -ForegroundColor Red
            Write-Log $logMsg
            Write-LogError $logMsg
        }
    }

    if ($changed) { 
        $service = Get-Service -Name $_.Service 
        $logMsg = "Service: $($service.Name) - StartType: $($service.StartType) - Status: $($service.Status) updated."
        Write-Host $logMsg -ForegroundColor Green
        Write-Log $logMsg
    } else {
        $logMsg = "No changes for service $($service.Name)."
        Write-Host $logMsg -ForegroundColor Cyan
    }
}

Write-Host "Stop AppLock service" -ForegroundColor Red

AppIdTel.exe Stop
# Write-Host "Clean AppLock cache" -ForegroundColor yellow
# .\pulizia_cache_applocker.ps1
Write-Host "Set AppLock Policy" -ForegroundColor yellow
Set-AppLockerPolicy -XMLPolicy Applock-Policy.XML
Get-AppLockerPolicy -Local -Xml > AppLock-Status.XML
Write-Host "AppLock Policy set successfully. Look at AppLock-Status.XML for details." -ForegroundColor Green
Write-Host "Start AppLock service" -ForegroundColor Green
AppIdTel.exe Start
