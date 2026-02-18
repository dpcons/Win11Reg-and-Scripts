# Win11Reg-and-Scripts
Registry Keys and Script to customize Windows 11 
Folder Script contain all the scripts for AppLock Apply and Services Get and Set

**AppLock-Importer** 
get the XML originally generated from AppLock and import all settings inside the new machine
The XML file need to be named "Applock-Policy.XML"

**CreateServiceListCSV**
Create a file named "ServiceList.csv" reporting all the services Name, StartType, Status, Description (the long description shown in App Services)

**UpdateServices**
Get File created above and apply to a new machine that settings . It manage all the StartType value like Stopped, Manual, Automatic etc.

**ExportGitCommits**
Export the full commit history of a git repository to a file. Supports multiple output formats (TXT, CSV, JSON).
Usage:
- `.\ExportGitCommits.ps1` - Exports to CommitList.txt (default format)
- `.\ExportGitCommits.ps1 -Format CSV` - Exports to CommitList.csv
- `.\ExportGitCommits.ps1 -Format JSON -OutputPath "commits.json"` - Exports to custom JSON file

**AllRegFiles.reg**
In Data Folder this Reg file can be used for forcing several specific settings (Integrating what we implement with Services and AppLock)

**Spiegazione Servizi.txt**
Elenco dei servizi che abbiamo rilevato non attivarsi/disattivarsi o manifestare problemi di cambio status

**Installazione Pacchetto WMI**
Sotto la cartella \Data\WMI\ sono memorizzati i pacchetti relativi a Windows 11 24H2 nelle versioni it-IT e en-US, selezionare il pacchetto preferito a seconda della lingua. Per installare il pacchetto si puo' usare uno dei due seguenti metodi:
DISM

DISM /Online /Add-Capability /CapabilityName:WMIC~~~~0.0.1.0 /Source:\\server\FoD\ /LimitAccess

PowerShell

Add-WindowsCapability -Online -Name WMIC~~~~0.0.1.0 -Source "\\server\FoD\" -LimitAccess
Dove \\server\FoD e' il folder dove viene posizionato il pacchetto .cab

I pacchetti relativi a WMI sono distribuiti in una ISO a parte da quella dell'OS, denominata "Languages and Optional Features for Windows 11, version 24H2".
Ovviamente ogni nuova versione ha una sua versione del disco.
I pacchetti di WMIC sono reperibili sotto le cartelle

**Aggiornamento Driver**
Lo script per effettuare l'upgrade dei driver e' ForceUpdateDrivers.ps1
prima di lanciare lo script, editartelo inserendo il path corretto della cartella contenente tutti i driver di cui fare upgrade. salvare ed eseguire con diritti Administrator/System
A corollario sono stati creati anche gli script:

ElencaDriver.ps1 che elenca tutta la lista dei driver installati sulla macchina

EliminaDriver.ps1 che va eseguito con la sintassi EliminaDriver -InfFileName "nomefile.inf"






![image](https://github.com/dpcons/Win11Reg-and-Scripts/blob/main/Images/Esecuzione%20Update%20Service.jpg) Output of UpdateServices

