Import-Csv -Path .\ServicesList.csv | ForEach-Object 
{
    $changed = $false
    $service = Get-Service -Name $_.Service
    if ($service.StartType -ne $_.StartType) 
    {
        Write-Host "Cambio di StartType per il servizio $($service.Name)" -ForegroundColor Yellow
        $service | Set-Service -StartupType $_.StartType
        $changed = $true
    }
if($service.Status -ne $_.Status) 
    {
        Write-Host "Cambio di Status per il servizio $($service.Name)" -ForegroundColor Yellow
        if ($_.Status -eq "Running") 
        {
            Start-Service -Name $service.Name
        } elseif ($_.Status -eq "Stopped") 
        {
            Stop-Service -Name $service.Name
        }
        $changed = $true
    }

    if ($changed) 
    { 
        $service = Get-Service -Name $_.Service 
        Write-Host "Servizio: $($service.Name) - StartType: $($service.StartType) - Status: $($service.Status) aggiornato." -ForegroundColor Green
    } 
    else 
    {
        Write-Host "Nessun cambiamento per il servizio $($service.Name)." -ForegroundColor Cyan
    }
}
