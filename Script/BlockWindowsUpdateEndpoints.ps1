<#
.SYNOPSIS
    Block or unblock Windows Update related endpoints via Windows Firewall and/or hosts file.

.DESCRIPTION
    This script adds outbound firewall rules (per FQDN) and/or hosts file entries to block known
    Windows Update, Microsoft Store, and content delivery domains used by Windows Update.

    ACTIONS:
      - Block    : Add firewall rules and/or hosts file entries.
      - Unblock  : Remove firewall rules and hosts entries previously added by this script.
      - Status   : Display current block status (rules + hosts markers).

.PARAMETER Action
    One of: Block | Unblock | Status (required)

.PARAMETER HostsOnly
    Only modify the hosts file.

.PARAMETER FirewallOnly
    Only create/remove firewall rules. (Ignored if HostsOnly is also specified.)

.NOTES
    - Must be run elevated (Administrator).
    - Blocking update endpoints can cause: Windows Store failures, Defender definition update failures,
      long system hangs during update checks, telemetry/backoff spam in logs.
    - This is for lab / kiosk / offline / snapshot environments. Prefer using WSUS / Policy / Notify mode in production.
    - Domain list is best-effort; Microsoft changes infrastructure frequently.
    - FQDN firewall rules rely on DNS name resolution at connection time; cached IPs might still work briefly.

    Hosts markers added with trailing comment:  # WUControlBlock
    Firewall rules grouped under: WUControl-UpdateBlock

    Backup of original hosts file is made once at: %ProgramData%\WUControl\hosts-backup-<date>.txt

.VERSION
    1.0.0
#>
[CmdletBinding()] param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Block','Unblock','Status')]
    [string]$Action,

    [switch]$HostsOnly,
    [switch]$FirewallOnly
)

function Assert-Admin {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'This script must be run as Administrator.'
    }
}

Assert-Admin
$ErrorActionPreference = 'Stop'

# --- Configuration ---
$groupName = 'WUControl-UpdateBlock'
$marker    = '# WUControlBlock'
$programDataRoot = Join-Path $env:ProgramData 'WUControl'
if (-not (Test-Path -LiteralPath $programDataRoot)) { New-Item -ItemType Directory -Path $programDataRoot -Force | Out-Null }

$hostsPath = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'

# Core FQDNs (curated; may expand). Caution: Some also affect Store/Edge components.
$domains = @(
    'windowsupdate.microsoft.com',
    'update.microsoft.com',
    'download.windowsupdate.com',
    'wustat.windows.com',
    'ntservicepack.microsoft.com',
    'wucontentdelivery.microsoft.com',
    'tlu.dl.delivery.mp.microsoft.com',
    'dl.delivery.mp.microsoft.com',
    'fe2.update.microsoft.com',
    'emdl.ws.microsoft.com',
    'sls.update.microsoft.com',
    'fg.v4.download.windowsupdate.com',
    'assets1.xboxlive.com',
    'assets2.xboxlive.com',
    'xboxexperiencesprod.experimentation.xboxlive.com',
    'xflight.xboxlive.com',
    'xvcf1.xboxlive.com'
)

if ($HostsOnly -and $FirewallOnly) {
    Write-Warning 'Both -HostsOnly and -FirewallOnly specified. Proceeding with hosts only.'
    $FirewallOnly = $false
}

$doHosts    = $true
$doFirewall = $true
if ($HostsOnly) { $doFirewall = $false }
elseif ($FirewallOnly) { $doHosts = $false }

function Backup-HostsOnce {
    if (-not (Test-Path -LiteralPath $hostsPath)) { throw "Hosts file not found at $hostsPath" }
    $existingBackup = Get-ChildItem -Path $programDataRoot -Filter 'hosts-backup-*.txt' | Select-Object -First 1
    if (-not $existingBackup) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        Copy-Item -Path $hostsPath -Destination (Join-Path $programDataRoot "hosts-backup-$stamp.txt") -Force
        Write-Host "[*] Backup of hosts created." -ForegroundColor DarkGray
    }
}

function Add-HostsBlocks {
    Backup-HostsOnce
    $hostsContent = Get-Content -Path $hostsPath -ErrorAction Stop
    $current = [string]::Join("`n", $hostsContent)
    $added = 0
    foreach ($d in $domains) {
        if ($current -notmatch "^0\.0\.0\.0\s+$([regex]::Escape($d))\s+$([regex]::Escape($marker))" -and $current -notmatch "^127\.0\.0\.1\s+$([regex]::Escape($d))\s+$([regex]::Escape($marker))") {
            Add-Content -Path $hostsPath -Value ("0.0.0.0 `t{0} `t{1}" -f $d,$marker)
            $added++
        }
    }
    Write-Host "    Hosts entries added: $added" -ForegroundColor DarkGray
}

function Remove-HostsBlocks {
    if (-not (Test-Path -LiteralPath $hostsPath)) { return }
    $lines = Get-Content -Path $hostsPath -ErrorAction Stop
    $new = $lines | Where-Object { $_ -notmatch "\s$([regex]::Escape($marker))$" }
    if ($new.Count -ne $lines.Count) {
        $new | Set-Content -Path $hostsPath -Encoding ASCII
        Write-Host "    Hosts entries removed: $($lines.Count - $new.Count)" -ForegroundColor DarkGray
    } else {
        Write-Host '    No hosts marker lines to remove.' -ForegroundColor DarkGray
    }
}

function Add-FirewallRules {
    $existing = Get-NetFirewallRule -Group $groupName -ErrorAction SilentlyContinue
    $existingFqdns = @()
    if ($existing) {
        foreach ($r in $existing) {
            try { $props = Get-NetFirewallRule -Name $r.Name | Get-NetFirewallAddressFilter -ErrorAction SilentlyContinue; if ($props.RemoteFqdn) { $existingFqdns += $props.RemoteFqdn } } catch { }
        }
    }
    $created = 0
    foreach ($d in $domains) {
        if ($existingFqdns -contains $d) { continue }
        try {
            New-NetFirewallRule -DisplayName "Block WU $d" -Group $groupName -Direction Outbound -Action Block -RemoteFqdn $d -Profile Any -Enabled True -ErrorAction SilentlyContinue | Out-Null
            $created++
        } catch { }
    }
    Write-Host "    Firewall rules created: $created" -ForegroundColor DarkGray
}

function Remove-FirewallRules {
    $rules = Get-NetFirewallRule -Group $groupName -ErrorAction SilentlyContinue
    if ($rules) {
        $count = $rules.Count
        $rules | Remove-NetFirewallRule -ErrorAction SilentlyContinue
        Write-Host "    Firewall rules removed: $count" -ForegroundColor DarkGray
    } else {
        Write-Host '    No firewall rules to remove.' -ForegroundColor DarkGray
    }
}

function Get-Status {
    $rules = Get-NetFirewallRule -Group $groupName -ErrorAction SilentlyContinue
    $ruleList = @()
    if ($rules) {
        foreach ($r in $rules) {
            $fq = (Get-NetFirewallRule -Name $r.Name | Get-NetFirewallAddressFilter -ErrorAction SilentlyContinue).RemoteFqdn
            $ruleList += [PSCustomObject]@{ Name=$r.DisplayName; FQDN=$fq; Enabled=$r.Enabled }
        }
    }
    $hostsLines = @()
    if (Test-Path -LiteralPath $hostsPath) {
        $hostsLines = Get-Content -Path $hostsPath | Where-Object { $_ -match "\s$([regex]::Escape($marker))$" }
    }
    [PSCustomObject]@{
        FirewallRules = $ruleList
        HostsEntries  = $hostsLines
        DomainsTargeted = $domains
    }
}

switch ($Action) {
    'Block' {
        Write-Host '[*] Blocking Windows Update endpoints (lab mode) ...' -ForegroundColor Cyan
        if ($doFirewall) { Add-FirewallRules }
        if ($doHosts)    { Add-HostsBlocks }
        Write-Host '[+] Block operation complete. Status:' -ForegroundColor Green
        Get-Status
    }
    'Unblock' {
        Write-Host '[*] Removing endpoint blocks ...' -ForegroundColor Cyan
        if ($doFirewall) { Remove-FirewallRules }
        if ($doHosts)    { Remove-HostsBlocks }
        Write-Host '[+] Unblock operation complete. Status:' -ForegroundColor Green
        Get-Status
    }
    'Status' {
        Write-Host '[*] Gathering current endpoint block status ...' -ForegroundColor Cyan
        Get-Status
    }
}

Write-Host "\nUsage examples:" -ForegroundColor Yellow
Write-Host "  Block both hosts + firewall : .\\BlockWindowsUpdateEndpoints.ps1 -Action Block" -ForegroundColor Yellow
Write-Host "  Block hosts only            : .\\BlockWindowsUpdateEndpoints.ps1 -Action Block -HostsOnly" -ForegroundColor Yellow
Write-Host "  Block firewall only         : .\\BlockWindowsUpdateEndpoints.ps1 -Action Block -FirewallOnly" -ForegroundColor Yellow
Write-Host "  Show status                 : .\\BlockWindowsUpdateEndpoints.ps1 -Action Status" -ForegroundColor Yellow
Write-Host "  Unblock everything          : .\\BlockWindowsUpdateEndpoints.ps1 -Action Unblock" -ForegroundColor Yellow

Write-Host "\nIMPORTANT: Expect Microsoft Store / Defender update disruption while blocked." -ForegroundColor Magenta
