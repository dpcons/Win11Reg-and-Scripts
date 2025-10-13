<#
.SYNOPSIS
    Force Update Drivers with Comprehensive Logging
    
.DESCRIPTION
    This script installs/updates drivers from a specified folder and logs all operations and errors.
    Enhanced version with detailed logging capabilities for operation tracking and troubleshooting.
    
.PARAMETER DriverFolder
    Path to the folder containing driver files (.inf). Default: "C:\DriversUpdate"
    
.PARAMETER LogFolder
    Path where log files will be created. Default: "C:\INST_LOG"
    
.PARAMETER Verbose
    Enable verbose logging output to console
    
.EXAMPLE
    .\ForceUpdateDrivers.ps1
    
.EXAMPLE
    .\ForceUpdateDrivers.ps1 -DriverFolder "D:\MyDrivers" -LogFolder "C:\Logs" -Verbose
    
.NOTES
    Author: Enhanced for Poste Italiane
            Modificato da Riccardo De Santi 30/09/25: aggiunta gestione del controllo hardware
                                                      Tipo PDL
                                                      File spia per controllo eventuale sostituzione drivers
                                                      Riavvio computer in ogni caso
    Version: 2.1.0
    Requires: Administrator privileges

#######################################################
Error codes:

RC-PS  1: some error occured during update drivers
RC-PS  2: no drivers processed
RC-PS 10: app completata correttamente o già eseguita
RC-PS 20: sistema operativo non supportato
RC-PS 80: tipo PDL non supportato (cartella STAR o SDP mancante)
RC-PS 81: componente mancante (Su PDL T&T manca C:\STAR\Inizia\Inizia.bat)
RC-PS 82: nome macchina T&T non valido (ottavo carattere non è C)
RC-PS 83: nome macchina T&T non valido (nono carattere è L o B)
RC-PS 84: componente D mancante (manca path D:\RILASCI_SWD)
RC-PS 85: nome macchina SDP non valido (primo carattere non è U)
RC-PS 86: nome macchina SDP non valido (nono carattere è L o B)
RC-PS 87: missing Spy File
RC-PS 88: invalid Spy File version
RC-PS 90: hardware computer incompatibile
    
#>

# param (
#    [Parameter(Mandatory=$false)]
#    [string]$DriverFolder = "C:\DriversUpdate",
    
#    [Parameter(Mandatory=$false)]
#    [string]$LogFolder = "C:\INST_LOG",
    
#    [Parameter(Mandatory=$false)]
#    [switch]$Verbose
#)

$Verbose = $true
#####################################################
# Initialize environment variables
#####################################################

$scriptVersion = "2.1.0"
$startTime = Get-Date
$computerName = [Net.Dns]::GetHostName()
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$nomemacchina = [Net.Dns]::GetHostName()
$pathesecuzione = Resolve-Path . | Select-Object Path -ExpandProperty Path
$logTimestamp = $startTime.ToString("yyyyMMdd_HHmmss")
$DriverFolder = "C:\Temp\Update_Drivers_HP800G9\Drivers_HP800G9"
$LogFolder = "C:\Temp\Update_Drivers_HP800G9"

# Create log folder if it doesn't exist
if (-not (Test-Path -Path $LogFolder)) {
    try {
        New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
        Write-Host "Created log folder: $LogFolder" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to create log folder: $LogFolder. Error: $_"
        exit 1
    }
}

# Log file paths
$mainLogFile = Join-Path $LogFolder "ForceUpdateDrivers_$logTimestamp.log"
# $errorLogFile = Join-Path $LogFolder "ForceUpdateDrivers_$logTimestamp.err"
$summaryLogFile = Join-Path $LogFolder "ForceUpdateDrivers_Summary.log"

# Add a script-level variable to track if any errors occurred
$script:hasErrors = $false
$script:errorLogFile = $null

#####################################################
# Logging functions
#####################################################

function Write-LogMessage {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS", "DEBUG")]
        [string]$Level = "INFO",
        
        [Parameter(Mandatory=$false)]
        [switch]$WriteToConsole = $true
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to main log file
    try {
        Add-Content -Path $mainLogFile -Value $logEntry -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to write to log file: $_"
    }
    
    # Write to error log if it's an error
    if ($Level -eq "ERROR") {
        # Create error log file only on first error
        if (-not $script:hasErrors) {
            $script:hasErrors = $true
            $script:errorLogFile = Join-Path $LogFolder "ForceUpdateDrivers_$logTimestamp.err"
            try {
                # Create the error log file
                "" | Out-File -FilePath $script:errorLogFile -Encoding UTF8 -Force
            }
            catch {
                Write-Warning "Failed to create error log file: $_"
            }
        }
        
        # Write to error log
        if ($script:errorLogFile) {
            try {
                Add-Content -Path $script:errorLogFile -Value $logEntry -Encoding UTF8 -ErrorAction Stop
            }
            catch {
                Write-Warning "Failed to write to error log file: $_"
            }
        }
    }
    
    # Write to console based on level and verbose setting
    if ($WriteToConsole -or $Verbose) {
        switch ($Level) {
            "ERROR"   { Write-Host $logEntry -ForegroundColor Red }
            "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
            "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
            "DEBUG"   { if ($Verbose) { Write-Host $logEntry -ForegroundColor Magenta } }
            default   { Write-Host $logEntry -ForegroundColor White }
        }
    }
}

function Write-Summary {
    param (
        [Parameter(Mandatory=$true)]
        [hashtable]$Results
    )
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    $errorLogInfo = if ($script:hasErrors -and $script:errorLogFile) {
        "Error Log: $script:errorLogFile"
    } else {
        "Error Log: No errors occurred"
    }

    $summaryContent = @"
=====================================
FORCE UPDATE DRIVERS - EXECUTION SUMMARY
=====================================
Execution Date: $($startTime.ToString("yyyy-MM-dd HH:mm:ss"))
Computer Name: $computerName
User: $currentUser
Script Version: $scriptVersion
Duration: $($duration.ToString("hh\:mm\:ss"))

PARAMETERS:
Driver Folder: $DriverFolder
Log Folder: $LogFolder
Verbose Mode: $Verbose

RESULTS:
Total Drivers Found: $($Results.Total)
Successfully Installed: $($Results.Success)
Failed Installations: $($Results.Failed)
Skipped (Already Current): $($Results.Skipped)
Reboot Required: $($Results.RebootRequired)

SUCCESS RATE: $([math]::Round((($Results.Success + $Results.RebootRequired) / $Results.Total) * 100, 2))%

LOG FILES:
Main Log: $mainLogFile
$errorLogInfo
Summary Log: $summaryLogFile

=====================================
"@

    try {
        $summaryContent | Out-File -FilePath $summaryLogFile -Encoding UTF8 -Force
        Write-LogMessage "Summary written to: $summaryLogFile" -Level "INFO"
    }
    catch {
        Write-LogMessage "Failed to write summary file: $_" -Level "ERROR"
    }
}
#####################################################
# Main Script Execution
#####################################################

# Initialize log files
"" | Out-File -FilePath $mainLogFile -Encoding UTF8 -Force
# "" | Out-File -FilePath $errorLogFile -Encoding UTF8 -Force

Write-LogMessage "*****************************************************************************" -Level "INFO"
Write-LogMessage "* Poste Italiane - Certificazione Firenze - Riccardo De Santi" -Level "INFO"
Write-LogMessage "* FORCE UPDATE DRIVERS - Enhanced Version $scriptVersion" -Level "INFO"
Write-LogMessage "* Driver Update Utility" -Level "INFO"
Write-LogMessage "*****************************************************************************" -Level "INFO"
Write-LogMessage " " -Level "INFO"
Write-LogMessage "Execution started on computer: $computerName by user: $currentUser" -Level "INFO"
Write-LogMessage "Driver folder: $DriverFolder" -Level "INFO"
Write-LogMessage "Log folder: $LogFolder" -Level "INFO"
Write-LogMessage " " -Level "INFO"

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Write-LogMessage "WARNING: Script is not running as Administrator. Some operations may fail." -Level "WARNING"
}
else {
    Write-LogMessage "Script running with Administrator privileges." -Level "SUCCESS"
}

##############################################################
# Check OS Version
##############################################################

Write-LogMessage "Checking OS version..." -Level "INFO"
$versioneOS= (Get-ComputerInfo | Select-Object -ExpandProperty OsName)
if ($versioneOS -ne "Microsoft Windows 10 Enterprise")
    {
     Write-LogMessage "20: unsupported Operating System." -Level "ERROR"
     Exit 20
    }
else
    {
     Write-LogMessage "OK: supported Operating System." -Level "SUCCESS"
    }

# --------------------------------------------------------
# Check Workstation type
# --------------------------------------------------------

Write-LogMessage "Check workstation type..." -Level "INFO"

$cartellaSDP = "C:\SDP\PERIFERICHE\MULTIFUNZIONE\STAMPANTEMULTIFUNZIONE.VBS"
$cartellaSTAR = "C:\STAR"
$presenzaSTAR = (Test-Path -Path $cartellaSTAR)
if ($presenzaSTAR -eq 'True')
    {
     $iniziaBAT = "C:\STAR\Inizia\inizia.bat"
     $presenzainiziaBAT = (Test-Path -Path $iniziaBAT)
     if ($presenzainiziaBAT -eq 'True')
        {
         $ottavocarattere = $nomemacchina[7]
         if ($ottavocarattere -eq "C")
            {
             $nonocarattere = $nomemacchina[8]
             if ($nonocarattere -eq "L" -or $nonocarattere -eq "B")
                {
                 Write-LogMessage "83: invalid hostname." -Level "ERROR"
                 Exit 83
                }
            }
         else
            {
             Write-LogMessage "82: invalid hostname." -Level "ERROR"
             Exit 82
            }
        }
     else
        {
         Write-LogMessage "81: missing component." -Level "ERROR"
         Exit 81
        }
    }
elseif ($presenzaSDP = (Test-Path -Path $cartellaSDP))
    {
     if ($presenzaSDP -eq 'True')
        {
         $RilasciSWD = "D:\RilasciSWD"
         $presenzaRilasciSWD = (Test-Path -Path $RilasciSWD)
         if ($presenzaRilasciSWD -eq 'True')
            {
             $primocarattere = $nomemacchina[0]
             if ($primocarattere -eq "U")
                {
                 $ottavocarattere = $nomemacchina[7]
                 if ($ottavocarattere -eq "L" -or $ottavocarattere -eq "B")
                    {
                     Write-LogMessage "86: invalid hostname." -Level "ERROR"
                     Exit 86
                    }
                }
             else
                {
                 Write-LogMessage "85: invalid hostname." -Level "ERROR"
                 Exit 85
                }
            }
         else
            {
             Write-LogMessage "84: missing component." -Level "ERROR"
             Exit 84
            }
        }
    }
else
    {
     Write-LogMessage "80: invalid workstation type." -Level "ERROR"
     Exit 80
    }

Write-LogMessage "OK: correct workstation type." -Level "SUCCESS"

####################################################
# Check computer model
####################################################

Write-LogMessage "Check computer hardware..." -Level "INFO"

$compatibleComputer = "HP Elite Mini 800 G9"
$computerModel = (Get-WmiObject -Class Win32_ComputerSystem -ErrorAction 'silentlycontinue').Model
if ($computerModel -match $compatibleComputer)
    {
     Write-LogMessage "$computerModel" -Level "INFO"
     Write-LogMessage "OK: correct computer hardware." -Level "SUCCESS"
    }
else
    {
     Write-LogMessage "$computerModel" -Level "INFO"
     Write-LogMessage "90: incorrect computer hardware." -Level "ERROR"
     Exit 90
    }

# Validate driver folder exists
if (-not (Test-Path -Path $DriverFolder)) {
    Write-LogMessage "ERROR: Driver folder not found: $DriverFolder" -Level "ERROR"
    Write-LogMessage "Please ensure the driver folder exists and is accessible." -Level "ERROR"
    exit 1
}

# Check Spy file
#Per renderlo generalizzato si puo' usare il seguente:
# $spiaHPInfo = Join-Path $DriverFolder "Drivers_HP800G9\sp157369\src\HPInfo.txt"
$spiaHPInfo = "C:\Temp\Update_Drivers_HP800G9\Drivers_HP800G9\sp157369\src\HPInfo.txt"
$HashHPInfo = "848287874858B56AECC152F67F0D126B7F6B4D61FCE9FA4CFDAE20022D2FE7A3"
if (-NOT (Test-Path $spiaHPInfo))
    {
     Write-LogMessage "87: missing driver component." -Level "ERROR"
     Exit 87
    }
else
    {
     $checkHashHPInfo = (Get-FileHash $spiaHPInfo | Select-Object -ExpandProperty Hash)
     if ($checkHashHPInfo -ne $HashHPInfo)
        {
         Write-LogMessage "88: invalid drivers version." -Level "ERROR"
         Exit 88
        }
    }

Write-LogMessage "Driver folder validated successfully: $DriverFolder" -Level "SUCCESS"

# Find all .inf files in the driver folder
Write-LogMessage "Searching for .inf files in driver folder..." -Level "INFO"

try {
    $driverFiles = Get-ChildItem -Path $DriverFolder -Recurse -Filter *.inf -ErrorAction Stop
    Write-LogMessage "Found $($driverFiles.Count) .inf files in the driver folder" -Level "SUCCESS"
}
catch {
    Write-LogMessage "ERROR: Failed to enumerate driver files: $_" -Level "ERROR"
    exit 1
}

if ($driverFiles.Count -eq 0) {
    Write-LogMessage "WARNING: No .inf files found in the specified driver folder." -Level "WARNING"
    Write-LogMessage "Execution completed with no actions taken." -Level "INFO"
    exit 0
}

# Initialize counters for summary
$results = @{
    Total = $driverFiles.Count
    Success = 0
    Failed = 0
    Skipped = 0
    RebootRequired = 0
}

Write-LogMessage "Starting driver installation process..." -Level "INFO"
Write-LogMessage "=======================================" -Level "INFO"

# Process each driver file
$currentDriver = 0
foreach ($driver in $driverFiles) {
    $currentDriver++
    $progressPercent = [math]::Round(($currentDriver / $driverFiles.Count) * 100, 1)
    
    Write-LogMessage "[$currentDriver/$($driverFiles.Count)] ($progressPercent%) Processing: $($driver.Name)" -Level "INFO"
    Write-LogMessage "Full path: $($driver.FullName)" -Level "DEBUG"
    
    try {
        # Check if driver file is accessible
        if (-not (Test-Path -Path $driver.FullName -PathType Leaf)) {
            Write-LogMessage "ERROR: Driver file is not accessible: $($driver.FullName)" -Level "ERROR"
            $results.Failed++
            continue
        }
        
        Write-LogMessage "Installing driver: $($driver.Name)" -Level "INFO"
        
        # Execute pnputil command and capture output
        $pnpOutput = pnputil /add-driver "$($driver.FullName)" /install 2>&1
        $exitCode = $LASTEXITCODE
        
        # Log the pnputil output
        Write-LogMessage "PnPUtil output for $($driver.Name):" -Level "DEBUG"
        if ($pnpOutput) {
            foreach ($line in $pnpOutput) {
                Write-LogMessage "  $line" -Level "DEBUG" -WriteToConsole:$false
            }
        }
        
        # Analyze the result based on exit code and output
        if ($exitCode -eq 0) {
            # Check if driver was already current
            if ($pnpOutput -match "already has a better matching or same driver installed|The specified driver package is not applicable to this computer|A newer version of the driver package already exists in the driver store") {
                Write-LogMessage "Driver $($driver.Name) - Already current (skipped)" -Level "INFO"
                $results.Skipped++
            }
            else {
                Write-LogMessage "Driver $($driver.Name) - Successfully installed" -Level "SUCCESS"
                $results.Success++
            }
        }
        elseif ($exitCode -eq 3010) {
            # Exit code 3010 means success but reboot required
            Write-LogMessage "Driver $($driver.Name) - Successfully installed (reboot required)" -Level "SUCCESS"
            $results.RebootRequired++
        }
        elseif ($exitCode -eq 259) {
            # Exit code 259 means Not installed because already present so log it as skipped and not error
            Write-LogMessage "Driver $($driver.Name) - Not installed (already present)" -Level "INFO"
            $results.Skipped++
        }
        else {
            # Check if the output indicates reboot is required despite non-zero exit code
            if ($pnpOutput -match "reboot.*required|restart.*required|requires.*reboot|requires.*restart") {
                Write-LogMessage "Driver $($driver.Name) - Successfully installed (reboot required)" -Level "SUCCESS"
                $results.RebootRequired++
            }
            # Check if it's a driver already present case that returned non-zero exit code
            elseif ($pnpOutput -match "already has a better matching or same driver installed|The specified driver package is not applicable to this computer|A newer version of the driver package already exists in the driver store") {
                Write-LogMessage "Driver $($driver.Name) - Already current (skipped)" -Level "INFO"
                $results.Skipped++
            }
            else {
                Write-LogMessage "Driver $($driver.Name) - Installation failed (Exit Code: $exitCode)" -Level "ERROR"
                if ($pnpOutput) {
                    Write-LogMessage "Error details: $($pnpOutput -join '; ')" -Level "ERROR"
                }
                $results.Failed++
            }
        }
    }
    catch {
        Write-LogMessage "ERROR: Exception occurred while processing $($driver.Name): $_" -Level "ERROR"
        $results.Failed++
    }
    
    Write-LogMessage "---" -Level "DEBUG" -WriteToConsole:$false
}

Write-LogMessage "===================================================================" -Level "INFO"
Write-LogMessage "Driver installation process completed." -Level "INFO"
Write-LogMessage "" -Level "INFO"

# Display results summary
Write-LogMessage "EXECUTION SUMMARY:" -Level "INFO"
Write-LogMessage "Total drivers processed: $($results.Total)" -Level "INFO"
Write-LogMessage "Successfully installed: $($results.Success)" -Level "SUCCESS"
Write-LogMessage "Successfully installed (reboot required): $($results.RebootRequired)" -Level "SUCCESS"
Write-LogMessage "Already current (skipped): $($results.Skipped)" -Level "INFO"
Write-LogMessage "Failed installations: $($results.Failed)" -Level $(if ($results.Failed -gt 0) { "ERROR" } else { "INFO" })

if ($results.Total -gt 0) {
    $successRate = [math]::Round((($results.Success + $results.RebootRequired) / $results.Total) * 100, 2)
    Write-LogMessage "Success rate: $successRate%" -Level $(if ($successRate -ge 80) { "SUCCESS" } elseif ($successRate -ge 50) { "WARNING" } else { "INFO" })
}

# Write summary to file
Write-Summary -Results $results

Write-LogMessage "" -Level "INFO"
Write-LogMessage "Log files created:" -Level "INFO"
Write-LogMessage "  Main log: $mainLogFile" -Level "INFO"
if ($script:hasErrors -and $script:errorLogFile) {
    Write-LogMessage "  Error log: $script:errorLogFile" -Level "INFO"
}
Write-LogMessage "  Summary: $summaryLogFile" -Level "INFO"

$endTime = Get-Date
$totalDuration = $endTime - $startTime
Write-LogMessage "Total execution time: $($totalDuration.ToString("hh\:mm\:ss"))" -Level "INFO"
Write-LogMessage "Script execution completed." -Level "SUCCESS"

# Set exit code based on results
if ($results.Failed -gt 0) {
    Write-LogMessage "Reboot computer..." -Level "INFO"
    Write-LogMessage "-------------------------------------------------------------" -Level "INFO"
    shutdown.exe /r /f /t 10
    Start-Sleep -Seconds 3
    exit 1  # Some failures occurred
}
elseif ($results.Success -eq 0 -and $results.Skipped -eq 0) {
    Write-LogMessage "Reboot computer..." -Level "INFO"
    Write-LogMessage "-------------------------------------------------------------" -Level "INFO"
    shutdown.exe /r /f /t 10
    Start-Sleep -Seconds 3
    exit 2  # No drivers processed
}
else {
    Write-LogMessage "Reboot computer..." -Level "INFO"
    Write-LogMessage "-------------------------------------------------------------" -Level "INFO"
    shutdown.exe /r /f /t 10
    Start-Sleep -Seconds 3
    exit 10  # Success
}