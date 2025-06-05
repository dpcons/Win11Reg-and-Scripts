$logFile = ".\UpdateServices.log"

function Write-Log {
    param (
        [string]$Message,
        [string]$Color = "White"
    )
    # Scrivi su file
    $Message | Out-File -FilePath $logFile -Append -Encoding UTF8
    # Scrivi a video
    Write-Host $Message -ForegroundColor $Color
}

Import-Csv -Path .\ServiceList.csv | ForEach-Object {
    $changed = $false
    $service = Get-Service -Name $_.Service -ErrorAction SilentlyContinue

    if (-not $service) {
        Write-Log "Service $($_.Service) not found." "Red"
        return
    }

    if ($service.StartType -ne $_.StartType) {
        Write-Log "Changing StartType for service $($service.Name)" "Yellow"
        try {
            $service | Set-Service -StartupType $_.StartType -ErrorAction Stop
            $changed = $true
        } catch {
            Write-Log "Error changing StartType for $($service.Name): $_" "Red"
        }
    }

    if ($service.Status -ne $_.Status) {
        Write-Log "Changing Status for service $($service.Name)" "Yellow"
        try {
            if ($_.Status -eq "Running") {
                Start-Service -Name $service.Name -ErrorAction Stop
            } elseif ($_.Status -eq "Stopped") {
                Stop-Service -Name $service.Name -ErrorAction Stop
            }
            $changed = $true
        } catch {
            Write-Log "Error changing Status for $($service.Name): $_" "Red"
        }
    }

    if ($changed) { 
        $service = Get-Service -Name $_.Service 
        Write-Log "Service: $($service.Name) - StartType: $($service.StartType) - Status: $($service.Status) updated." "Green"
    } else {
        Write-Log "No changes for service $($service.Name)." "Cyan"
    }
}

Set-AppLockerPolicy -XMLPolicy Applock-Policy.XML
