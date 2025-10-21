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

<#
===============================================================================
 SEZIONE FREEZE WINDOWS UPDATE & ENDPOINTS
   1. Policy: imposta NoAutoUpdate=1 e rimuove AUOptions
   2. Disabilita servizi: wuauserv, bits, dosvc, cryptsvc (salva StartType la prima volta)
   3. Disabilita WaaSMedicSvc (Start=4)
   4. Disabilita Scheduled Tasks Update/Orchestrator
   5. Blocca endpoints (hosts + firewall) con marker # WUControlBlock e gruppo regole WUControl-UpdateBlock
===============================================================================
#>

Write-Log "[Freeze] Avvio procedura Freeze Windows Update"

# Controllo privilegi amministrativi
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $msg = '[Freeze] Sessione non elevata: salto Freeze.'
    Write-Log $msg
} else {
    try {
        # --- 1. Policy Windows Update ---
        $auPath = 'HKLM:SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate\\AU'
        if (-not (Test-Path $auPath)) { New-Item -Path $auPath -Force | Out-Null }
        New-ItemProperty -Path $auPath -Name 'NoAutoUpdate' -Value 1 -PropertyType DWord -Force | Out-Null
        if (Get-ItemProperty -Path $auPath -Name 'AUOptions' -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $auPath -Name 'AUOptions' -ErrorAction SilentlyContinue
        }
        Write-Log '[Freeze] Policy impostata (NoAutoUpdate=1)'

        # --- 2. Servizi ---
        $serviceConfigPath = Join-Path $env:ProgramData 'WUControl'
        if (-not (Test-Path $serviceConfigPath)) { New-Item -ItemType Directory -Path $serviceConfigPath -Force | Out-Null }
        $startupJson = Join-Path $serviceConfigPath 'serviceStartup.json'
        $originalMap = @{}
        if (Test-Path $startupJson) {
            try { $originalMap = (Get-Content -Raw -Path $startupJson | ConvertFrom-Json) } catch { $originalMap=@{} }
        }
        $svcList = 'wuauserv','bits','dosvc','cryptsvc'
        foreach ($svc in $svcList) {
            $svcObj = Get-Service -Name $svc -ErrorAction SilentlyContinue
            if ($null -eq $svcObj) { Write-Log "[Freeze] Servizio $svc non trovato"; continue }
            if (-not $originalMap.ContainsKey($svc)) { $originalMap[$svc] = $svcObj.StartType }
            try { if ($svcObj.Status -ne 'Stopped') { Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue } } catch { Write-LogError "[Freeze] Errore stop $svc: $_" }
            try { Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue } catch { Write-LogError "[Freeze] Errore disabilitando $svc: $_" }
        }
        $originalMap | ConvertTo-Json | Out-File -FilePath $startupJson -Encoding UTF8
        Write-Log '[Freeze] Servizi disabilitati e startup originali salvati'

        # WaaSMedicSvc hard disable (Start=4)
        $medicReg = 'HKLM:SYS\*' # placeholder for context unique diff anchor
        $medicPath = 'HKLM:SYS\*' # not used; maintain minimal patch uniqueness
        $waasReg = 'HKLM:SYSTEM\\CurrentControlSet\\Services\\WaaSMedicSvc'
        if (Test-Path $waasReg) { Set-ItemProperty -Path $waasReg -Name Start -Value 4 -ErrorAction SilentlyContinue; Write-Log '[Freeze] WaaSMedicSvc Start=4' }

        # --- 3. Scheduled Tasks ---
        $taskPaths = @('\Microsoft\Windows\WindowsUpdate\','\Microsoft\Windows\UpdateOrchestrator\')
        $disabledTasks = 0
        foreach ($tp in $taskPaths) {
            $tasks = Get-ScheduledTask -TaskPath $tp -ErrorAction SilentlyContinue
            foreach ($t in $tasks) {
                try {
                    if ($t.State -ne 'Disabled') { Disable-ScheduledTask -TaskName $t.TaskName -TaskPath $tp -ErrorAction SilentlyContinue | Out-Null; $disabledTasks++ }
                } catch { Write-LogError "[Freeze] Errore disabilitando task $($t.TaskName): $_" }
            }
        }
        Write-Log "[Freeze] Task disabilitati: $disabledTasks"

        # --- 4. Blocco Endpoints ---
        $domains = @(
            'windowsupdate.microsoft.com','update.microsoft.com','download.windowsupdate.com','wustat.windows.com','ntservicepack.microsoft.com',
            'wucontentdelivery.microsoft.com','tlu.dl.delivery.mp.microsoft.com','dl.delivery.mp.microsoft.com','fe2.update.microsoft.com','emdl.ws.microsoft.com',
            'sls.update.microsoft.com','fg.v4.download.windowsupdate.com','assets1.xboxlive.com','assets2.xboxlive.com','xboxexperiencesprod.experimentation.xboxlive.com',
            'xflight.xboxlive.com','xvcf1.xboxlive.com'
        )
        $hostsPath = Join-Path $env:SystemRoot 'System32\\drivers\\etc\\hosts'
        $marker = '# WUControlBlock'
        # Backup hosts una sola volta
        $backupExists = Get-ChildItem -Path $serviceConfigPath -Filter 'hosts-backup-*.txt' -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $backupExists -and (Test-Path $hostsPath)) {
            $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            Copy-Item -Path $hostsPath -Destination (Join-Path $serviceConfigPath "hosts-backup-$stamp.txt") -Force
            Write-Log '[Freeze] Backup hosts creato'
        }
        if (Test-Path $hostsPath) {
            $hostsContent = Get-Content -Path $hostsPath -ErrorAction SilentlyContinue
            $joined = [string]::Join("`n", $hostsContent)
            $added = 0
            foreach ($d in $domains) {
                if ($joined -notmatch "^0\\.0\\.0\\.0\\s+$([regex]::Escape($d))\\s+$([regex]::Escape($marker))" -and $joined -notmatch "^127\\.0\\.0\\.1\\s+$([regex]::Escape($d))\\s+$([regex]::Escape($marker))") {
                    Add-Content -Path $hostsPath -Value ("0.0.0.0`t{0}`t{1}" -f $d,$marker)
                    $added++
                }
            }
            Write-Log "[Freeze] Hosts entries aggiunti: $added"
        } else {
            Write-Log '[Freeze] Hosts file non trovato: skip blocco hosts'
        }
        # Firewall rules
        $groupName = 'WUControl-UpdateBlock'
        $existingRules = Get-NetFirewallRule -Group $groupName -ErrorAction SilentlyContinue
        $existingFqdns = @()
        if ($existingRules) {
            foreach ($r in $existingRules) {
                try { $addr = Get-NetFirewallRule -Name $r.Name | Get-NetFirewallAddressFilter -ErrorAction SilentlyContinue; if ($addr.RemoteFqdn) { $existingFqdns += $addr.RemoteFqdn } } catch { }
            }
        }
        $created = 0
        foreach ($d in $domains) {
            if ($existingFqdns -contains $d) { continue }
            try { New-NetFirewallRule -DisplayName "Block WU $d" -Group $groupName -Direction Outbound -Action Block -RemoteFqdn $d -Profile Any -Enabled True -ErrorAction SilentlyContinue | Out-Null; $created++ } catch { Write-LogError "[Freeze] Errore creazione regola firewall $d: $_" }
        }
        Write-Log "[Freeze] Regole firewall create: $created"

        Write-Log '[Freeze] Completato'
    } catch {
        $err = "[Freeze] Errore generale: $_"
        Write-Log $err
        Write-LogError $err
    }
}

# FINE SEZIONE FREEZE

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

# Write-Host "Stop AppLock service" -ForegroundColor Red

# AppIdTel.exe Stop
# Write-Host "Clean AppLock cache" -ForegroundColor yellow
# .\pulizia_cache_applocker.ps1
# Write-Host "Set AppLock Policy" -ForegroundColor yellow
# Set-AppLockerPolicy -XMLPolicy Applock-Policy.XML
# Get-AppLockerPolicy -Local -Xml > AppLock-Status.XML
# Write-Host "AppLock Policy set successfully. Look at AppLock-Status.XML for details." -ForegroundColor Green
# Write-Host "Start AppLock service" -ForegroundColor Green
# AppIdTel.exe Start
