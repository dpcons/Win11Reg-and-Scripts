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

# Added W11
$AppPackages += "Microsoft.Windows.Photos"
$AppPackages += "Microsoft.Windows.Camera"
$AppPackages += "Microsoft.WindowsCamera"                # ADDED: Alternative Camera name
$AppPackages += "Microsoft.WindowsTerminal"
$AppPackages += "Microsoft.WindowsSoundRecorder"
$AppPackages += "Microsoft.WindowsStore"
$AppPackages += "Microsoft.WindowsMaps"
$AppPackages += "Microsoft.MicrosoftStickyNotes"
$AppPackages += "Microsoft.BingNews"
$AppPackages += "Microsoft.BingSports"
$AppPackages += "Microsoft.MoviesTV"
$AppPackages += "Microsoft.Windows.Cortana"
$AppPackages += "Microsoft.WindowsCommunicationsApps"
$AppPackages += "MicrosoftWindows.Client.CBS"
$AppPackages += "Microsoft.StorePurchaseApp"
$AppPackages += "Microsoft.ScreenSketch"
$AppPackages += "MicrosoftWindows.LKG.DesktopSpotlight"
$AppPackages += "Microsoft.AV1VideoExtension"
$AppPackages += "MicrosoftWindows.LKG.AccountsService"
$AppPackages += "Microsoft.OutlookForWindows"
$AppPackages += "MicrosoftWindows.Client.Core"
$AppPackages += "MicrosoftWindows.LKG.SpeechRuntime"
$AppPackages += "Clipchamp.Clipchamp"
$AppPackages += "MicrosoftCorporationII.QuickAssist"
$AppPackages += "Microsoft.BingSearch"
$AppPackages += "Microsoft.Windows.StartMenuExperienceHost"
$AppPackages += "Microsoft.ApplicationCompatibilityEnhancements"
$AppPackages += "Microsoft.Windows.XGpuEjectDialog"
$AppPackages += "Windows.CBSPreview"
$AppPackages += "Microsoft.MPEG2VideoExtension"
$AppPackages += "Microsoft.Windows.SecureAssessmentBrowser"
$AppPackages += "windows.immersivecontrolpanel"
$AppPackages += "Microsoft.Copilot"
$AppPackages += "Microsoft.AVCEncoderVideoExtension"
$AppPackages += "Microsoft.Windows.PeopleExperienceHost"
$AppPackages += "Microsoft.Windows.NarratorQuickStart"
$AppPackages += "Microsoft.PowerAutomateDesktop"
$AppPackages += "Microsoft.LockApp"
$AppPackages += "Microsoft.VP9VideoExtensions"
$AppPackages += "MicrosoftWindows.LKG.TwinSxS"
$AppPackages += "Microsoft.Windows.AssignedAccessLockApp"
$AppPackages += "MicrosoftWindows.LKG.IrisService"
$AppPackages += "MicrosoftWindows.LKG.RulesEngine"
$AppPackages += "Microsoft.Windows.PinningConfirmationDialog"
$AppPackages += "Microsoft.Windows.DevHome"
$AppPackages += "MICROSOFT.ONEDRIVESYNC" 
$AppPackages += "Microsoft.Todos"
$AppPackages += "Microsoft.ECApp"
$AppPackages += "MicrosoftWindows.CrossDevice"

# ADDED: Missing Windows 11 packages
$AppPackages += "Microsoft.GamingApp"                    # Main Gaming App (Windows 11)
$AppPackages += "Microsoft.XboxGameCallableUI"           # Xbox Game Callable UI  
$AppPackages += "Microsoft.Paint"                        # New Paint app for Windows 11




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