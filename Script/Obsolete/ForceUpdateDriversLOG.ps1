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
    Version: 2.0.0
    Requires: Administrator privileges
    
#>

param (
    [Parameter(Mandatory=$false)]
    [string]$DriverFolder = "C:\DriversUpdate",
    
    [Parameter(Mandatory=$false)]
    [string]$LogFolder = "C:\INST_LOG",
    
    [Parameter(Mandatory=$false)]
    [switch]$Verbose
)

#####################################################
# Initialize environment variables
#####################################################

$scriptVersion = "2.0.0"
$startTime = Get-Date
$computerName = [Net.Dns]::GetHostName()
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$logTimestamp = $startTime.ToString("yyyyMMdd_HHmmss")

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
$errorLogFile = Join-Path $LogFolder "ForceUpdateDrivers_$logTimestamp.err"
$summaryLogFile = Join-Path $LogFolder "ForceUpdateDrivers_Summary.log"

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
        try {
            Add-Content -Path $errorLogFile -Value $logEntry -Encoding UTF8 -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to write to error log file: $_"
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

SUCCESS RATE: $([math]::Round(($Results.Success / $Results.Total) * 100, 2))%

LOG FILES:
Main Log: $mainLogFile
Error Log: $errorLogFile
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
"" | Out-File -FilePath $errorLogFile -Encoding UTF8 -Force

Write-LogMessage "**************************************************************" -Level "INFO"
Write-LogMessage "* FORCE UPDATE DRIVERS - Enhanced Version $scriptVersion" -Level "INFO"
Write-LogMessage "* Poste Italiane - Driver Update Utility" -Level "INFO"
Write-LogMessage "**************************************************************" -Level "INFO"
Write-LogMessage "" -Level "INFO"
Write-LogMessage "Execution started on computer: $computerName by user: $currentUser" -Level "INFO"
Write-LogMessage "Driver folder: $DriverFolder" -Level "INFO"
Write-LogMessage "Log folder: $LogFolder" -Level "INFO"
Write-LogMessage "" -Level "INFO"

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Write-LogMessage "WARNING: Script is not running as Administrator. Some operations may fail." -Level "WARNING"
}
else {
    Write-LogMessage "Script running with Administrator privileges." -Level "SUCCESS"
}

# Validate driver folder exists
if (-not (Test-Path -Path $DriverFolder)) {
    Write-LogMessage "ERROR: Driver folder not found: $DriverFolder" -Level "ERROR"
    Write-LogMessage "Please ensure the driver folder exists and is accessible." -Level "ERROR"
    exit 1
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
            if ($pnpOutput -match "already has a better matching or same driver installed") {
                Write-LogMessage "Driver $($driver.Name) - Already current (skipped)" -Level "WARNING"
                $results.Skipped++
            }
            else {
                Write-LogMessage "Driver $($driver.Name) - Successfully installed" -Level "SUCCESS"
                $results.Success++
            }
        }
        else {
            Write-LogMessage "Driver $($driver.Name) - Installation failed (Exit Code: $exitCode)" -Level "ERROR"
            if ($pnpOutput) {
                Write-LogMessage "Error details: $($pnpOutput -join '; ')" -Level "ERROR"
            }
            $results.Failed++
        }
    }
    catch {
        Write-LogMessage "ERROR: Exception occurred while processing $($driver.Name): $_" -Level "ERROR"
        $results.Failed++
    }
    
    Write-LogMessage "---" -Level "DEBUG" -WriteToConsole:$false
}

Write-LogMessage "=======================================" -Level "INFO"
Write-LogMessage "Driver installation process completed." -Level "INFO"
Write-LogMessage "" -Level "INFO"

# Display results summary
Write-LogMessage "EXECUTION SUMMARY:" -Level "INFO"
Write-LogMessage "Total drivers processed: $($results.Total)" -Level "INFO"
Write-LogMessage "Successfully installed: $($results.Success)" -Level "SUCCESS"
Write-LogMessage "Already current (skipped): $($results.Skipped)" -Level "WARNING"
Write-LogMessage "Failed installations: $($results.Failed)" -Level $(if ($results.Failed -gt 0) { "ERROR" } else { "INFO" })

if ($results.Total -gt 0) {
    $successRate = [math]::Round(($results.Success / $results.Total) * 100, 2)
    Write-LogMessage "Success rate: $successRate%" -Level $(if ($successRate -ge 80) { "SUCCESS" } elseif ($successRate -ge 50) { "WARNING" } else { "ERROR" })
}

# Write summary to file
Write-Summary -Results $results

Write-LogMessage "" -Level "INFO"
Write-LogMessage "Log files created:" -Level "INFO"
Write-LogMessage "  Main log: $mainLogFile" -Level "INFO"
Write-LogMessage "  Error log: $errorLogFile" -Level "INFO"
Write-LogMessage "  Summary: $summaryLogFile" -Level "INFO"

$endTime = Get-Date
$totalDuration = $endTime - $startTime
Write-LogMessage "Total execution time: $($totalDuration.ToString("hh\:mm\:ss"))" -Level "INFO"
Write-LogMessage "Script execution completed." -Level "SUCCESS"

# Set exit code based on results
if ($results.Failed -gt 0) {
    exit 1  # Some failures occurred
}
elseif ($results.Success -eq 0 -and $results.Skipped -eq 0) {
    exit 2  # No drivers processed
}
else {
    exit 0  # Success
}