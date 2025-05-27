Get-Service | ForEach-Object {
    $serviceName = $_.Name
    $status = $_.Status
    $startType = (Get-CimInstance -ClassName Win32_Service -Filter "Name='$serviceName'").StartMode

    [PSCustomObject]@{
        Service   = $serviceName
        StartType = $startType
        Status    = $status
    }
} | Export-Csv -Path .\ServiceList.csv -NoTypeInformation -Encoding UTF8

Write-Host "ServiceList.csv generato correttamente." -ForegroundColor Green