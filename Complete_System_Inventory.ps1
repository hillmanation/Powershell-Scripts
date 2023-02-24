Import-Module ActiveDirectory,Dhcpserver

$output = @()
$scopeID = $NULL
$scopeName = $NULL
$systems = Get-ADComputer -filter * -Properties Name,OperatingSystem | where { $_.OperatingSystem -like "*Windows*" } | Select-Object Name,OperatingSystem | Sort-Object -Property Name

ForEach ($system in $systems) { 

    $IP = (Resolve-DNSName -Name $system.Name -Type A).IPAddress

    $scopeID = (Get-Dhcpserverv4lease -ComputerName dc-1 -ipaddress $IP -ErrorAction SilentlyContinue).ScopeId.IPAddresstoString

    If ($scopeID -eq $NULL) { $scopeID = "No Lease" }

    If ($scopeID -eq "No Lease") { $scopeName = "No Lease" }
    Else { $scopename = (Get-DhcpServerv4Scope -ComputerName dc-1 -ScopeId $scopeID -ErrorAction SilentlyContinue).Name }

    $properties = [pscustomobject]@{SystemName=[string]$system.Name;OperatingSystem=[string]$system.OperatingSystem;IPAddress=[string]$IP;ScopeID=$scopeID;ScopeName=[string]$scopename}
    $output += New-Object -TypeName PSObject $properties

 }
 
 $zeroclients = Get-DhcpServerv4Scope -computername dc-1 | Get-DhcpServerv4Lease -computername dc-1 | where { $_.HostName -like "ZC*" } | Select-Object -Property HostName,IPAddress,ScopeId| Sort-Object -Property Hostname

 ForEach ($zeroclient in $zeroclients) {

    $hostname = ($zeroclient.HostName).Substring(0,9)

    $IP = (Resolve-DNSName -Name $hostName -Type A).IPAddress

    $scopeID = (Get-Dhcpserverv4lease -ComputerName dc-1 -ipaddress $IP).ScopeId.IPAddresstoString

    If ($scopeID -eq $NULL) { $scopeID = "No Lease" }

    If ($scopeID -eq "No Lease") { $scopeName = "No Lease" }
    Else { $scopename = (Get-DhcpServerv4Scope -ComputerName dc-1 -ScopeId $scopeID -ErrorAction SilentlyContinue).Name }

    $properties = [pscustomobject]@{SystemName=[string]$hostName;OperatingSystem=[string]"ZeroClient";IPAddress=[string]$IP;ScopeID=$scopeID;ScopeName=[string]$scopename}
    $output += New-Object -TypeName PSObject $properties

 }

 $output | Export-CSV -Path "\Script Output\Complete System Inventory 8-27-21.csv" -NoTypeInformation