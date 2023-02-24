Set-ExecutionPolicy -ExecutionPolicy Unrestricted 
Import-Module ActiveDirectory

$computers = (Get-ADComputer -filter * -Properties Name | where { $_.Name -like "*BEL*" -or $_.Name -like "*GRC*" -or $_.Name -like "*ADMIN*" -and $_.Name -notlike "*GOLD*" } | Select Name).Name

ForEach ($computer in $computers) {

echo "Enabling root account for computer $computer..."

$script = 'wmic /node:"' + $computer + '" process call create "cmd.exe /c net user root /active:yes"'

cmd.exe /c "$script"

$active = (cmd.exe /node:$computer /c "net user root")

$active[5]
 }