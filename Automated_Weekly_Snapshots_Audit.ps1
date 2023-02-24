import-module VMWare.VimAutomation.Core
$output = @()

## Get Secure Credentials
---> $username = 'svc_account_name'
---> $encrypted = Get-Content "\\Share\Folder_1\Folder_2\Gatekeeper\svc_account_name\svc_account_name-secure.txt" | ConvertTo-SecureString
$credential = New-Object System.Management.Automation.PsCredential($username, $encrypted)

## Check for year and month folder in Log folder and create folders if needed
$filedate = Get-Date -Format "_MM_dd_yyyy"
$blank,$month,$day,$year = $filedate.split("_")
$fullmonth = get-date -UFormat %B
---> $rootfolder = "\\Share\Folder_1\Folder_2\vCenter Snapshots Audit\"
$yearFolder = $rootfolder + $year + "\"

If (!(Test-Path -Path $yearfolder)) { New-Item -Path $rootfolder -Name $year -ItemType Directory -Force | Out-Null }

$monthfolder = $month + " - " + $fullmonth
$logfolder = $yearfolder + "\" + $monthfolder + "\"

If (!(Test-Path -Path $logfolder)) { New-Item -Path $yearfolder -Name $monthfolder -ItemType Directory -Force | Out-Null }

$fileNameCSV = $logFolder + "vCenter_Snapshots_Audit_" + $fullmonth + ".csv"

## Connect to the vCenter server
---> $server = 'vcsa-server_name'
---> ##$vcenter = Connect-VIServer -Server $server -User 'svc_account_name' -Password ''
$vcenter = Connect-VIServer -Server $server -Credential $credential

$snapshots = Get-VM | Get-Snapshot | where { ($_.Name -notlike "IT Snapshot*") -and $_.Created -lt (Get-Date).AddDays(-7)} | Select VM,Created

If ($snapshots -ne $NULL) {
    $removed = Get-VM | Get-Snapshot | where { ($_.Name -notlike "IT Snapshot*") -and $_.Created -lt (Get-Date).AddDays(-7)} | Remove-Snapshot -RunAsync -Confirm:$false | Select ObjectID,StartTime
    $n = 0

    ForEach ($snapshot in $snapshots) { $output += [pscustomobject]@{ VM=$snapshot.VM; SnapshotCreated=$snapshot.Created; ObjectID=$removed[$n].ObjectID; RemovalDate=$removed[$n].StartTime }; $n++ }

    $output | Export-CSV -Path $fileNameCSV -Append -NoTypeInformation
}

$vcenter | Disconnect-VIServer -force -Confirm:$false