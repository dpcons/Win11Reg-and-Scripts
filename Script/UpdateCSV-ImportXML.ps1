Import-Csv -Path .\ServiceList.csv | ForEach-Object {
    $changed = $false
    $service = Get-Service -Name $_.Service -ErrorAction SilentlyContinue

    if (-not $service) {
        Write-Host "Service $($_.Service) not found." -ForegroundColor Red
        return
    }

    if ($service.StartType -ne $_.StartType) {
        Write-Host "Changing StartType for service $($service.Name)" -ForegroundColor Yellow
        try {
            $service | Set-Service -StartupType $_.StartType -ErrorAction Stop
            $changed = $true
        } catch {
            Write-Host "Error changing StartType for $($service.Name): $_" -ForegroundColor Red
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
            Write-Host "Error changing Status for $($service.Name): $_" -ForegroundColor Red
        }
    }

    if ($changed) { 
        $service = Get-Service -Name $_.Service 
        Write-Host "Service: $($service.Name) - StartType: $($service.StartType) - Status: $($service.Status) updated." -ForegroundColor Green
    } else {
        Write-Host "No changes for service $($service.Name)." -ForegroundColor Cyan
    }
}


Set-AppLockerPolicy -XMLPolicy Applock-Policy.XML