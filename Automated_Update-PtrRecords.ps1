Import-Module ActiveDirectory
Set-ExecutionPolicy -ExecutionPolicy Bypass -Force -Confirm:$false

$date = Get-Date
$descrDate = Get-Date -Format "MM/dd/yyyy"
$dnsrecords = Get-DnsServerResourceRecord -computername '' -ZoneName '' | where { $_.HostName -notlike "_*" -and $_.Hostname -notlike "*@*" }

## Check for year and month folder in Log folder and create folders if needed
$filedate = Get-Date -Format "_MM_dd_yyyy"
$blank,$month,$day,$year = $filedate.split("_")
$fullmonth = get-date -UFormat %B
---> $rootfolder = "\\Share\Folder_1\Folder_2\DNS PTR Update Logs\"
$yearFolder = $rootfolder + $year + "\"

If (!(Test-Path -Path $yearfolder)) { New-Item -Path $rootfolder -Name $year -ItemType Directory -Force | Out-Null }

$fileNameLog = $rootfolder + $year + "\" + $month + "-" + $fullmonth + "-DNS PTR Updates Log.txt"

## Start text log
"-------------------$date------------------`r`n----------Starting DNS PTR Record Update Script---------`r`n--------------------------------------------------------`r`n`r`n" | Out-File $filenameLog -Append

ForEach ($record in $dnsrecords) {

    $recordip = $record.RecordData.IPv4Address.IPAddressToString
    $1st,$2nd,$3rd,$name = $recordip.split(".")
    $zone = $3rd + "." + $2nd + "." + $1st + ".in-addr.arpa"
    $ptrname = $record.HostName + ".com"

    If (!(Get-DnsServerZone -ComputerName '' -Name $zone -ErrorAction SilentlyContinue)) {

        "No zone found for $zone, creating the zone...." | Out-File $fileNameLog -Append
        Add-DnsServerPrimaryZone -ComputerName '' -Name $zone -ReplicationScope Forest }

    If (!(Get-DnsServerResourceRecord -ComputerName '' -rrtype Ptr -Name $name -ZoneName $zone -ErrorAction SilentlyContinue)) {

        "Creating Ptr record for $ptrname in zone $zone..." | Out-File $fileNameLog -Append
        Add-DnsServerResourceRecordPtr -ComputerName '' -Name $name -ZoneName $zone -AllowUpdateAny -TimeToLive 00:20:00 -AgeRecord -PtrDomainName "$ptrName" }

    If (!(!(Get-DnsServerResourceRecord -ComputerName '' -rrtype Ptr -Name $name -ZoneName $zone -ErrorAction SilentlyContinue))) { <#"Ptr record for $ptrname exists in zone $zone..." | Out-File $fileNameLog -Append#> }
    Else { "`r`nCreating Ptr record for $ptrname failed!!!`r`n`r`n" | Out-File $fileNameLog -Append }

}

$end = Get-Date
$elapsed = (($end - $date).totalSeconds)
"`r`n----------DNS PTR Record Update Script Completed-----------`r`n--------------------$end--------------------`r`n--------------Elapsed time: $elapsed seconds-------------`r`n`r`n" | Out-File $filenameLog -Append