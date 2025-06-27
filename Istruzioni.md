Checklist e sequenza operazioni per Implementare le personalizzazioni del Sistema:
Creare o prelevare la *ServiceList.csv* e il *AppLock-Policy.xml* da utilizzare.
Lo script principale per la applicazione delle modifiche e' *UpdateCSV-ImportXML.ps1*
Sulla macchina obiettivo e' necessario configurare l'esecuzione di un task schedulato **alla accensione della macchina** (prima del logon) come da screenshot:

![alt text](Images\TaskAppLock01.png)
![alt text](Images\TaskAppLock02.png)

Lo script *UpdateCSV-ImportXML.ps1* deve essere eseguito alla accensione della macchina (prima del logon) i due file dei servizi e delle policy devono risiedere nella stassa folder dello script. L'esecuzione genera un log su file dell'esito delle operazioni *UpdateService.txt*.
