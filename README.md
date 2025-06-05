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

**AllRegFiles.reg**
In Data Folder this Reg file can be used for forcing several specific settings (Integrating what we implement with Services and AppLock)

**Spiegazione Servizi.txt**
Elenco dei servizi che abbiamo rilevato non attivarsi/disattivarsi o manifestare problemi di cambio status

![image](https://github.com/dpcons/Win11Reg-and-Scripts/blob/main/Images/Esecuzione%20Update%20Service.jpg) Output of UpdateServices

