Import-Csv -Path .\ServiceList.csv | ForEach-Object {
    $changed = $false
    $service = Get-Service -Name $_.Service -ErrorAction SilentlyContinue

    if (-not $service) {
        Write-Host "Servizio $($_.Service) non trovato." -ForegroundColor Red
        return
    }

    if ($service.StartType -ne $_.StartType) {
        Write-Host "Cambio di StartType per il servizio $($service.Name)" -ForegroundColor Yellow
        try {
            $service | Set-Service -StartupType $_.StartType -ErrorAction Stop
            $changed = $true
        } catch {
            Write-Host "Errore durante il cambio di StartType per $($service.Name): $_" -ForegroundColor Red
        }
    }

    if ($service.Status -ne $_.Status) {
        Write-Host "Cambio di Status per il servizio $($service.Name)" -ForegroundColor Yellow
        try {
            if ($_.Status -eq "Running") {
                Start-Service -Name $service.Name -ErrorAction Stop
            } elseif ($_.Status -eq "Stopped") {
                Stop-Service -Name $service.Name -ErrorAction Stop
            }
            $changed = $true
        } catch {
            Write-Host "Errore durante il cambio di Status per $($service.Name): $_" -ForegroundColor Red
        }
    }

    if ($changed) { 
        $service = Get-Service -Name $_.Service 
        Write-Host "Servizio: $($service.Name) - StartType: $($service.StartType) - Status: $($service.Status) aggiornato." -ForegroundColor Green
    } else {
        Write-Host "Nessun cambiamento per il servizio $($service.Name)." -ForegroundColor Cyan
    }
}