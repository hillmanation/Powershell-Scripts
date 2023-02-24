$computers = (Get-ADComputer -filter * -Properties Name,OperatingSystem -SearchBase "" -SearchScope Subtree | where { $_.OperatingSystem -like "*Windows*" -and $_.Name -like "wks-*" } | Select-Object Name).Name

ForEach ($computer in $computers) {
$computer = $computer.Name

echo $computer + "`r`n--------------------------------"
$script = 'wmic /node:"' + $computer + '" process call create "cmd.exe /c winrm quickconfig -quiet"'
cmd.exe /c $script

}