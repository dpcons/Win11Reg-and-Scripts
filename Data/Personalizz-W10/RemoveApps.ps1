<#

Poste Italiane - Riccardo De Santi

Disinstallatore applicazioni Windows non necessarie

21/01/2025 - Ver. 1.0.0

#>

#####################################################
# Inizializzazione variabili di ambiente
#####################################################

$ver = "1.0.0"
$ora = Get-Date
$log = "C:\INST_LOG\RemoveApps.log"
$nomemacchina = [Net.Dns]::GetHostName()
$utente = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

#####################################################
# Dichiarazioni funzioni
#####################################################

function WriteLog {

    param (
           [string]$logtext
          )

$logriga = "$ora " + "$logtext"
Add-Content $log -Value $logriga

                  }

#######################################################################
# Inizializzazione file di log
#######################################################################
WriteLog "**************************************************************"
WriteLog "* Poste Italiane - Certificazione Firenze"
WriteLog "* Riccardo De Santi"
WriteLog "* Disinstallatore applicazioni Windows versione $ver"
WriteLog "**************************************************************"
WriteLog ""
WriteLog "Procedura eseguita sul computer $nomemacchina da $utente"
WriteLog ""

WriteLog "Creazione array Appx da disinstallare..."

$AppPackages  = @()
$AppPackages += 'Microsoft.3DBuilder'
$AppPackages += 'Microsoft.BingWeather'
# $AppPackages += 'Microsoft.DesktopAppInstaller'
$AppPackages += 'Microsoft.GetHelp'
$AppPackages += 'Microsoft.Getstarted'
$AppPackages += 'Microsoft.Messaging'
$AppPackages += 'Microsoft.Microsoft3DViewer'
$AppPackages += 'Microsoft.MicrosoftOfficeHub'
$AppPackages += 'Microsoft.MicrosoftSolitaireCollection'
$AppPackages += 'Microsoft.MixedReality.Portal'
$AppPackages += 'Microsoft.MSPaint'
$AppPackages += 'Microsoft.People'
$AppPackages += 'Microsoft.Print3D'
$AppPackages += 'Microsoft.Office.OneNote'
$AppPackages += 'Microsoft.OneConnect'
$AppPackages += 'Microsoft.SkypeApp'
$AppPackages += 'Microsoft.Wallet'
$AppPackages += 'Microsoft.WindowsAlarms'
$AppPackages += 'microsoft.windowscommunicationsapps'
$AppPackages += 'Microsoft.WindowsFeedbackHub'
$AppPackages += 'Microsoft.WindowsMaps'
$AppPackages += 'Microsoft.Xbox.TCUI'
$AppPackages += 'Microsoft.XboxApp'
$AppPackages += 'Microsoft.XboxGameOverlay'
$AppPackages += 'Microsoft.XboxGamingOverlay'
$AppPackages += 'Microsoft.XboxIdentityProvider'
$AppPackages += 'Microsoft.XboxSpeechToTextOverlay'
$AppPackages += 'Microsoft.YourPhone'
$AppPackages += 'Microsoft.ZuneMusic'
$AppPackages += 'Microsoft.ZuneVideo'

Start-Sleep -Seconds 3
WriteLog "OK."
WriteLog "Inizio disinstallazione Appx..."

ForEach ($App in $AppPackages)
{
    $Packages = Get-AppxPackage | Where-Object {$_.Name -eq $App}
    if ($Packages -ne $null)
    {
        WriteLog "Disinstallazione Appx Package: $App"
        foreach ($Package in $Packages)
        {
            Remove-AppxPackage -Package $Package.PackageFullName -ErrorAction SilentlyContinue
        }
    }
    else
    {
        WriteLog "Appx non trovata: $App"
    }
  
    $ProvisionedPackage = Get-AppxProvisionedPackage -Online | Where-Object {$_.displayName -eq $App}
    if ($ProvisionedPackage -ne $null)
    {
        WriteLog "Disinstallazione Appx Provisioned: $App"
        Remove-AppxProvisionedPackage -Online -packagename $ProvisionedPackage.PackageName -ErrorAction SilentlyContinue
    }
    else
    {
        WriteLog "Provisioned Appx non trovata: $App"
    } 
}

WriteLog ""
WriteLog "0: disinstallazione Appx terminata."
Exit 0