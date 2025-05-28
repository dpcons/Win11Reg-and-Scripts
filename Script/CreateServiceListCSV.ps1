Get-Service | ForEach-Object {
    $serviceName = $_.Name
    $status = $_.Status
    $startType = (Get-CimInstance -ClassName Win32_Service -Filter "Name='$serviceName'").StartMode
    $description = (Get-CimInstance -ClassName Win32_Service -Filter "Name='$serviceName'").Description
    if (-not $description) {
        $description = "No description available"
    }

    [PSCustomObject]@{
        Service   = $serviceName
        StartType = $startType
        Status    = $status
        Description = $description
    }
} | Export-Csv -Path .\ServiceList.csv -NoTypeInformation -Encoding UTF8

Write-Host "ServiceList.csv generato correttamente." -ForegroundColor Green