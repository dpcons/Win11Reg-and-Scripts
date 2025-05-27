# Win11Reg-and-Scripts
Registry Keys and Script to customize Windows 11 
Folder Script contain all the scripts for AppLock Apply and Services Get and Set

**AppLock-Importer** 
get the XML originally generated from AppLock and import all settings inside the new machine
The XML file need to be named "Applock-Policy.XML"

**CreateServiceListCSV**
Create a file named "ServiceList.csv" reporting all the services Name, StartType, Status

**UpdateServices**
Get File created above and apply to a new machine that settings . It manage all the StartType value like Stopped, Manual, Automatic etc.


<br/>
Output of UpdateServices <img width="450" src="https://github.com/dpcons/Win11Reg-and-Scripts/blob/main/Images/Esecuzione%20Update%20Service.jpg" style="vertical-align:middle">
<br/>
