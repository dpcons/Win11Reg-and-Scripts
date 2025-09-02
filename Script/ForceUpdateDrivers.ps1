# Percorso alla cartella dei driver
$driverFolder = "C:\DriversUpdate"

# Trova tutti i file .inf nella cartella (ricorsivamente)
$driverFiles = Get-ChildItem -Path $driverFolder -Recurse -Filter *.inf

# Conta i driver trovati
Write-Host "Trovati $($driverFiles.Count) file .inf. Inizio installazione..." -ForegroundColor Cyan

foreach ($driver in $driverFiles) {
    Write-Host "Installazione driver: $($driver.FullName)" -ForegroundColor Yellow
    pnputil /add-driver "$($driver.FullName)" /install
}

Write-Host "Installazione completata." -ForegroundColor Green