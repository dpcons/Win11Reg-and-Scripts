<#
.SYNOPSIS
    Unified Windows Update control & endpoint blocking manager for Windows 10/11.

.DESCRIPTION
    Consolidates the functionality of DisableWindowsUpdate.ps1 and BlockWindowsUpdateEndpoints.ps1 into a single tool.

    ACTIONS (core update behavior):
      Disable          - Disable automatic updates (policy + services + tasks + WaaSMedic hard disable)
      Enable           - Re-enable updates (restore services, tasks, clear policy)
      Notify           - Enable manual (notify for download) mode
      Status           - Show current Windows Update control state

    ENDPOINT ACTIONS:
      BlockEndpoints     - Add hosts +/or firewall FQDN blocks
      UnblockEndpoints   - Remove hosts + firewall blocks added by this script
      StatusEndpoints    - Show current endpoint block status

    COMPOSITE ACTIONS:
      Freeze           - Disable + BlockEndpoints (full lab freeze)
      Thaw             - UnblockEndpoints + Enable (restore normal)

    SWITCHES:
      -HostsOnly        (when used with endpoint actions) Only modify hosts file
      -FirewallOnly     (when used with endpoint actions) Only modify firewall

    DATA PERSISTENCE:
      Service startup types stored (first Disable) at: %ProgramData%\WUControl\serviceStartup.json
      Hosts backup stored once at: %ProgramData%\WUControl\hosts-backup-<timestamp>.txt
      Firewall rules grouped under: WUControl-UpdateBlock
      Hosts entries appended with marker: # WUControlBlock

    SAFE USAGE GUIDELINES:
      Prefer Notify over full Disable in production. Use Freeze only for offline / snapshot / lab scenarios.
      Endpoint blocking breaks Store, Defender AV updates, and possibly other Microsoft services.

.PARAMETER Action
    One of: Disable, Enable, Notify, Status, BlockEndpoints, UnblockEndpoints, StatusEndpoints, Freeze, Thaw

.PARAMETER HostsOnly
    With endpoint-related actions, only manipulate hosts file entries.

.PARAMETER FirewallOnly
    With endpoint-related actions, only manipulate firewall rules.

.EXAMPLES
    .\WindowsUpdateManager.ps1 -Action Status
    .\WindowsUpdateManager.ps1 -Action Disable
    .\WindowsUpdateManager.ps1 -Action BlockEndpoints -FirewallOnly
    .\WindowsUpdateManager.ps1 -Action Freeze
    .\WindowsUpdateManager.ps1 -Action Thaw

.NOTES
    Must be run elevated (Administrator).
    Version: 1.0.0
    Original scripts preserved for backward compatibility.
#>
[CmdletBinding()] param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Disable','Enable','Notify','Status','BlockEndpoints','UnblockEndpoints','StatusEndpoints','Freeze','Thaw')]
    [string]$Action,
    [switch]$HostsOnly,
    [switch]$FirewallOnly
)

# ------------------------------------------------------------
# Common Helpers
# ------------------------------------------------------------
function Assert-Admin {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'This script must be run in an elevated PowerShell session (Run as Administrator).'
    }
}

function New-DirectoryIfMissing($Path) { if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null } }

function Set-RegistryValueSafe {
    [CmdletBinding()] param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] $Value,
        [ValidateSet('String','DWord','QWord','Binary','MultiString','ExpandString')] [string]$Type = 'DWord'
    )
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
}
function Remove-RegistryValueSafe { param([string]$Path,[string]$Name) if (Test-Path -LiteralPath $Path) { try { Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue } catch { } } }

$programDataRoot = Join-Path $env:ProgramData 'WUControl'
New-DirectoryIfMissing $programDataRoot
$serviceStorePath = Join-Path $programDataRoot 'serviceStartup.json'

# ------------------------------------------------------------
# Windows Update Control Functions
# ------------------------------------------------------------
function Get-ServiceInfo($Names) {
    foreach ($n in $Names) {
        $svc = Get-Service -Name $n -ErrorAction SilentlyContinue
        if ($null -ne $svc) {
            $startType = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$n" -Name Start -ErrorAction SilentlyContinue).Start
            $mapped = switch ($startType) { 2 {'Automatic'} 3 {'Manual'} 4 {'Disabled'} 0 {'Boot'} 1 {'System'} Default {"$startType"} }
            [PSCustomObject]@{ Name=$n; Status=$svc.Status; StartType=$mapped }
        } else { [PSCustomObject]@{ Name=$n; Status='NotFound'; StartType='N/A' } }
    }
}
function Set-ServiceStartTypeRaw($Name,$StartValue) { $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$Name"; if (Test-Path $regPath) { Set-ItemProperty -Path $regPath -Name Start -Value $StartValue -Force } }
function Disable-WUServices { param([hashtable]$OriginalMap,[string[]]$Services) foreach ($svc in $Services) { $s = Get-Service -Name $svc -ErrorAction SilentlyContinue; if ($null -eq $s) { continue }; if (-not $OriginalMap.ContainsKey($svc)) { $OriginalMap[$svc] = $s.StartType }; try { if ($s.Status -ne 'Stopped') { Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue } } catch { }; try { Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue } catch { } } }
function Restore-WUServices { param([string]$StorePath) $defaults = @{ 'wuauserv'='Manual'; 'bits'='Manual'; 'dosvc'='Manual'; 'cryptsvc'='Automatic' }; $map=@{}; if (Test-Path -LiteralPath $StorePath) { try { $map = (Get-Content -Raw -Path $StorePath | ConvertFrom-Json) } catch { $map=@{} } }; foreach ($svc in $defaults.Keys) { $desired = $map[$svc]; if ([string]::IsNullOrWhiteSpace($desired)) { $desired = $defaults[$svc] }; try { Set-Service -Name $svc -StartupType $desired -ErrorAction SilentlyContinue } catch { } }; foreach ($svc in $defaults.Keys) { try { Start-Service -Name $svc -ErrorAction SilentlyContinue } catch { } } }
function Disable-WUTasks { $paths = @('\Microsoft\Windows\WindowsUpdate\','\Microsoft\Windows\UpdateOrchestrator\'); $disabled=0; foreach ($p in $paths) { $tasks = Get-ScheduledTask -TaskPath $p -ErrorAction SilentlyContinue; foreach ($t in $tasks) { try { if ($t.State -ne 'Disabled') { Disable-ScheduledTask -TaskName $t.TaskName -TaskPath $p -ErrorAction SilentlyContinue | Out-Null; $disabled++ } } catch { } } }; return $disabled }
function Enable-WUTasks { $paths = @('\Microsoft\Windows\WindowsUpdate\','\Microsoft\Windows\UpdateOrchestrator\'); $enabled=0; foreach ($p in $paths) { $tasks = Get-ScheduledTask -TaskPath $p -ErrorAction SilentlyContinue; foreach ($t in $tasks) { try { if ($t.State -eq 'Disabled') { Enable-ScheduledTask -TaskName $t.TaskName -TaskPath $p -ErrorAction SilentlyContinue | Out-Null; $enabled++ } } catch { } } }; return $enabled }
function Get-WUTaskStateSummary { $paths = @('\Microsoft\Windows\WindowsUpdate\','\Microsoft\Windows\UpdateOrchestrator\'); $sum = foreach ($p in $paths) { $tasks = Get-ScheduledTask -TaskPath $p -ErrorAction SilentlyContinue; foreach ($t in $tasks) { [PSCustomObject]@{ Path=$p; Task=$t.TaskName; State=$t.State } } }; return $sum }
function Get-WUStatus { $policyRoot='HKLM:SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate'; $auPath=Join-Path $policyRoot 'AU'; $noAuto=(Get-ItemProperty -Path $auPath -Name NoAutoUpdate -ErrorAction SilentlyContinue).NoAutoUpdate; $auOpt=(Get-ItemProperty -Path $auPath -Name AUOptions -ErrorAction SilentlyContinue).AUOptions; $services=Get-ServiceInfo -Names 'wuauserv','bits','dosvc','cryptsvc','WaaSMedicSvc'; $tasks=Get-WUTaskStateSummary; $medicStart=(Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc' -Name Start -ErrorAction SilentlyContinue).Start; $medicMapped=switch ($medicStart) {2 {'Automatic'} 3 {'Manual'} 4 {'Disabled'} Default {"$medicStart"}}; [PSCustomObject]@{ Policy_NoAutoUpdate=$noAuto; Policy_AUOptions=$auOpt; WaaSMedic_StartType=$medicMapped; Services=$services; Tasks=$tasks } }

# ------------------------------------------------------------
# Endpoint Blocking Functions
# ------------------------------------------------------------
$groupName = 'WUControl-UpdateBlock'
$marker    = '# WUControlBlock'
$hostsPath = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
$domains = @(
    'windowsupdate.microsoft.com','update.microsoft.com','download.windowsupdate.com','wustat.windows.com','ntservicepack.microsoft.com','wucontentdelivery.microsoft.com','tlu.dl.delivery.mp.microsoft.com','dl.delivery.mp.microsoft.com','fe2.update.microsoft.com','emdl.ws.microsoft.com','sls.update.microsoft.com','fg.v4.download.windowsupdate.com','assets1.xboxlive.com','assets2.xboxlive.com','xboxexperiencesprod.experimentation.xboxlive.com','xflight.xboxlive.com','xvcf1.xboxlive.com'
)
function Backup-HostsOnce { if (-not (Test-Path -LiteralPath $hostsPath)) { throw "Hosts file not found at $hostsPath" }; $existingBackup = Get-ChildItem -Path $programDataRoot -Filter 'hosts-backup-*.txt' | Select-Object -First 1; if (-not $existingBackup) { $stamp=Get-Date -Format 'yyyyMMdd-HHmmss'; Copy-Item -Path $hostsPath -Destination (Join-Path $programDataRoot "hosts-backup-$stamp.txt") -Force; Write-Verbose 'Hosts backup created.' } }
function Add-HostsBlocks { Backup-HostsOnce; $hostsContent = Get-Content -Path $hostsPath -ErrorAction Stop; $current=[string]::Join("`n",$hostsContent); $added=0; foreach ($d in $domains) { if ($current -notmatch "^0\.0\.0\.0\s+$([regex]::Escape($d))\s+$([regex]::Escape($marker))" -and $current -notmatch "^127\.0\.0\.1\s+$([regex]::Escape($d))\s+$([regex]::Escape($marker))") { Add-Content -Path $hostsPath -Value ("0.0.0.0`t{0}`t{1}" -f $d,$marker); $added++ } }; Write-Host "    Hosts entries added: $added" -ForegroundColor DarkGray }
function Remove-HostsBlocks { if (-not (Test-Path -LiteralPath $hostsPath)) { return }; $lines=Get-Content -Path $hostsPath -ErrorAction Stop; $new=$lines | Where-Object { $_ -notmatch "\s$([regex]::Escape($marker))$" }; if ($new.Count -ne $lines.Count) { $new | Set-Content -Path $hostsPath -Encoding ASCII; Write-Host "    Hosts entries removed: $($lines.Count - $new.Count)" -ForegroundColor DarkGray } else { Write-Host '    No hosts marker lines to remove.' -ForegroundColor DarkGray } }
function Add-FirewallRules { $existing = Get-NetFirewallRule -Group $groupName -ErrorAction SilentlyContinue; $existingFqdns=@(); if ($existing) { foreach ($r in $existing) { try { $props=Get-NetFirewallRule -Name $r.Name | Get-NetFirewallAddressFilter -ErrorAction SilentlyContinue; if ($props.RemoteFqdn){ $existingFqdns += $props.RemoteFqdn } } catch { } } }; $created=0; foreach ($d in $domains) { if ($existingFqdns -contains $d) { continue }; try { New-NetFirewallRule -DisplayName "Block WU $d" -Group $groupName -Direction Outbound -Action Block -RemoteFqdn $d -Profile Any -Enabled True -ErrorAction SilentlyContinue | Out-Null; $created++ } catch { } }; Write-Host "    Firewall rules created: $created" -ForegroundColor DarkGray }
function Remove-FirewallRules { $rules=Get-NetFirewallRule -Group $groupName -ErrorAction SilentlyContinue; if ($rules) { $count=$rules.Count; $rules | Remove-NetFirewallRule -ErrorAction SilentlyContinue; Write-Host "    Firewall rules removed: $count" -ForegroundColor DarkGray } else { Write-Host '    No firewall rules to remove.' -ForegroundColor DarkGray } }
function Get-EndpointStatus { $rules = Get-NetFirewallRule -Group $groupName -ErrorAction SilentlyContinue; $ruleList=@(); if ($rules) { foreach ($r in $rules) { $fq=(Get-NetFirewallRule -Name $r.Name | Get-NetFirewallAddressFilter -ErrorAction SilentlyContinue).RemoteFqdn; $ruleList += [PSCustomObject]@{ Name=$r.DisplayName; FQDN=$fq; Enabled=$r.Enabled } } }; $hostsLines=@(); if (Test-Path -LiteralPath $hostsPath) { $hostsLines = Get-Content -Path $hostsPath | Where-Object { $_ -match "\s$([regex]::Escape($marker))$" } }; [PSCustomObject]@{ FirewallRules=$ruleList; HostsEntries=$hostsLines; DomainsTargeted=$domains } }

# ------------------------------------------------------------
# Execution Logic
# ------------------------------------------------------------
Assert-Admin
$ErrorActionPreference='Stop'

if ($HostsOnly -and $FirewallOnly) { Write-Warning 'Both -HostsOnly and -FirewallOnly specified; proceeding with hosts only.'; $FirewallOnly = $false }
$doHosts = $true; $doFirewall = $true
if ($HostsOnly) { $doFirewall=$false } elseif ($FirewallOnly) { $doHosts=$false }

$policyRoot='HKLM:SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
$auPath=Join-Path $policyRoot 'AU'

function Disable-WUCore {
    Write-Host '[*] Disabling Windows Update components...' -ForegroundColor Cyan
    $original = @{}
    if (Test-Path -LiteralPath $serviceStorePath) { try { $existing=(Get-Content -Raw -Path $serviceStorePath | ConvertFrom-Json); if ($existing) { $original=$existing } } catch { } }
    Set-RegistryValueSafe -Path $auPath -Name 'NoAutoUpdate' -Value 1 -Type DWord
    Remove-RegistryValueSafe -Path $auPath -Name 'AUOptions'
    $svcList='wuauserv','bits','dosvc','cryptsvc'
    Disable-WUServices -OriginalMap $original -Services $svcList
    $original | ConvertTo-Json | Out-File -FilePath $serviceStorePath -Encoding UTF8
    Set-ServiceStartTypeRaw -Name 'WaaSMedicSvc' -StartValue 4
    $disabledTasks = Disable-WUTasks
    Write-Host "    Disabled scheduled tasks: $disabledTasks" -ForegroundColor DarkGray
    Get-WUStatus
}
function Enable-WUCore {
    Write-Host '[*] Enabling Windows Update components...' -ForegroundColor Cyan
    Remove-RegistryValueSafe -Path $auPath -Name 'NoAutoUpdate'
    Remove-RegistryValueSafe -Path $auPath -Name 'AUOptions'
    Restore-WUServices -StorePath $serviceStorePath
    Set-ServiceStartTypeRaw -Name 'WaaSMedicSvc' -StartValue 3
    $enabledTasks = Enable-WUTasks
    Write-Host "    Re-enabled scheduled tasks: $enabledTasks" -ForegroundColor DarkGray
    Get-WUStatus
}
function Set-WUNotifyMode {
    Write-Host '[*] Setting Windows Update to Notify (manual) mode...' -ForegroundColor Cyan
    Remove-RegistryValueSafe -Path $auPath -Name 'NoAutoUpdate'
    Set-RegistryValueSafe -Path $auPath -Name 'AUOptions' -Value 2 -Type DWord
    Restore-WUServices -StorePath $serviceStorePath
    Enable-WUTasks | Out-Null
    Set-ServiceStartTypeRaw -Name 'WaaSMedicSvc' -StartValue 3
    Get-WUStatus
}
function Block-WUEndpointsCore {
    Write-Host '[*] Blocking Windows Update endpoints...' -ForegroundColor Cyan
    if ($doFirewall) { Add-FirewallRules }
    if ($doHosts) { Add-HostsBlocks }
    Get-EndpointStatus
}
function Unblock-WUEndpointsCore {
    Write-Host '[*] Removing endpoint blocks...' -ForegroundColor Cyan
    if ($doFirewall) { Remove-FirewallRules }
    if ($doHosts) { Remove-HostsBlocks }
    Get-EndpointStatus
}

$result = $null
switch ($Action) {
    'Disable'         { $result = Disable-WUCore; Write-Host '[+] Disable complete.' -ForegroundColor Green }
    'Enable'          { $result = Enable-WUCore;  Write-Host '[+] Enable complete.' -ForegroundColor Green }
    'Notify'          { $result = Set-WUNotifyMode;  Write-Host '[+] Notify mode active.' -ForegroundColor Green }
    'Status'          { Write-Host '[*] Gathering Windows Update status...' -ForegroundColor Cyan; $result = Get-WUStatus }
    'BlockEndpoints'  { $result = Block-WUEndpointsCore; Write-Host '[+] Endpoint block complete.' -ForegroundColor Green }
    'UnblockEndpoints'{ $result = Unblock-WUEndpointsCore; Write-Host '[+] Endpoint unblock complete.' -ForegroundColor Green }
    'StatusEndpoints' { Write-Host '[*] Gathering endpoint block status...' -ForegroundColor Cyan; $result = Get-EndpointStatus }
    'Freeze'          { Write-Host '[*] Freeze: Disable + BlockEndpoints' -ForegroundColor Cyan; $wu=Disable-WUCore; $ep=Block-WUEndpointsCore; $result=[PSCustomObject]@{ UpdateStatus=$wu; EndpointStatus=$ep }; Write-Host '[+] System frozen (updates disabled & endpoints blocked).' -ForegroundColor Green }
    'Thaw'            { Write-Host '[*] Thaw: UnblockEndpoints + Enable' -ForegroundColor Cyan; $ep=Unblock-WUEndpointsCore; $wu=Enable-WUCore; $result=[PSCustomObject]@{ EndpointStatus=$ep; UpdateStatus=$wu }; Write-Host '[+] System thawed (updates re-enabled & endpoints unblocked).' -ForegroundColor Green }
}

# Output object for pipelines
$result

Write-Host "\nUsage examples:" -ForegroundColor Yellow
Write-Host "  Status                  : .\\WindowsUpdateManager.ps1 -Action Status" -ForegroundColor Yellow
Write-Host "  Disable updates         : .\\WindowsUpdateManager.ps1 -Action Disable" -ForegroundColor Yellow
Write-Host "  Notify only             : .\\WindowsUpdateManager.ps1 -Action Notify" -ForegroundColor Yellow
Write-Host "  Block endpoints (all)   : .\\WindowsUpdateManager.ps1 -Action BlockEndpoints" -ForegroundColor Yellow
Write-Host "  Block hosts only        : .\\WindowsUpdateManager.ps1 -Action BlockEndpoints -HostsOnly" -ForegroundColor Yellow
Write-Host "  Freeze (full)           : .\\WindowsUpdateManager.ps1 -Action Freeze" -ForegroundColor Yellow
Write-Host "  Thaw (restore)          : .\\WindowsUpdateManager.ps1 -Action Thaw" -ForegroundColor Yellow
Write-Host "  Unblock endpoints       : .\\WindowsUpdateManager.ps1 -Action UnblockEndpoints" -ForegroundColor Yellow

Write-Host "\nNOTE: Endpoint blocking disrupts Store & Defender updates." -ForegroundColor Magenta
