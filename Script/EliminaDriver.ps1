param (
    [Parameter(Mandatory=$true)]
    [string]$InfFileName
)

# Ottieni tutti i driver installati
$drivers = pnputil /enum-drivers

# Trova il nome OEM associato al file .inf
$matchedDriver = $drivers | Where-Object { $_ -match $InfFileName }

if ($matchedDriver) {
    # Estrai il nome OEM (es. oem42.inf)
    $oemName = ($matchedDriver -split ":")[0].Trim()

    Write-Host "Driver trovato: $oemName. Procedo con la disinstallazione..." -ForegroundColor Yellow

    # Comando per disinstallare il driver
    pnputil /delete-driver $oemName /uninstall /force

    Write-Host "Driver $oemName rimosso." -ForegroundColor Green
} else {
    Write-Host "Nessun driver trovato per il file .inf specificato." -ForegroundColor Red
}