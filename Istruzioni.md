# Checklist e sequenza operazioni per Implementare le personalizzazioni del Sistema:
Creare o prelevare la *ServiceList.csv* e il *AppLock-Policy.xml* da utilizzare.
Lo script principale per la applicazione delle modifiche e' *UpdateCSV-ImportXML.ps1*
Sulla macchina obiettivo e' necessario configurare l'esecuzione di un task schedulato **alla accensione della macchina** (prima del logon) utilizzando lo script *CreateSchedTask.ps1* coadiuvato dal file di configurazione *AppLock-Policy.xml* disponibile nel folder Data.

Lo script *UpdateCSV-ImportXML.ps1* deve essere eseguito **come Amministratore (o SYSTEM)** se possibile  **alla accensione della macchina** (prima del logon) i due file dei servizi e delle policy devono risiedere nella stassa folder dello script. L'esecuzione genera un log su file dell'esito delle operazioni *UpdateService.txt*.

Quando si modificano servizi o policy e si applica lo script e' consigliabile riavviare la macchina (anche se dovrebbero applicarsi immediatamente le modifiche).



Vecchie indicazioni per creare il task:

![alt text](https://github.com/dpcons/Win11Reg-and-Scripts/blob/main/Images/TaskAppLock01.jpg)
![alt text](https://github.com/dpcons/Win11Reg-and-Scripts/blob/main/Images/TaskAppLock02.jpg)

