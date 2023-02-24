import-module activedirectory

$computers = (Get-ADComputer -Filter * | Where { $_.Name -like "WKS*" }).Name
$computers += 'LIC-3', 'SDSCV'
$output = @()
$drives = @()

ForEach ($computer in $computers) {
    
    $drives = Get-WmiObject win32_physicalmedia -ComputerName $computer | Select-Object Tag,SerialNumber

    ForEach ($drive in $drives) { $output += [pscustomobject]@{ Computer=$computer; Tag=$drive.Tag; SerialNumber=$drive.SerialNumber } }
}

$output | Export-CSV -Path "\Script Output\HDDSerialInventory92321.csv" -NoTypeInformation