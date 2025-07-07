# Define the path to the XML file
$xmlPath = ".\ApplockerTaskDefinition.xml"

# Define the task name
$taskName = "AppLocker"

# Register the task
Register-ScheduledTask -TaskName $taskName -Xml (Get-Content $xmlPath -Raw) -User "SYSTEM"
