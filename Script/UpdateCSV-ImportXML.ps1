$logFile = ".\UpdateServices.log"

# Sovrascrive il file di log (lo svuota all'avvio dello script)
"" | Out-File -FilePath $logFile -Encoding UTF8

function Write-Log {
    param (
        [string]$Message
    )
    # Scrivi solo su file
    $Message | Out-File -FilePath $logFile -Append -Encoding UTF8
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
       }
    }

    if ($service.Status -ne $_.Status) {
        Write-Host "Changing Status for service $($service.Name)" -ForegroundColor Yellow
        try {
            if ($_.Status -eq "Running") {
                Start-Service -Name $service.Name -Force -ErrorAction Stop
            } elseif ($_.Status -eq "Stopped") {
                Stop-Service -Name $service.Name -Force -ErrorAction Stop
            }
            $changed = $true
        } catch {
            $logMsg ="Error changing Status for $($service.Name): $_"
            Write-Host $logMsg -ForegroundColor Red
            Write-Log $logMsg
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

Set-AppLockerPolicy -XMLPolicy Applock-Policy.XML
