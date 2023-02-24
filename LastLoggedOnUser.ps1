Set-ExecutionPolicy Unrestricted -Force

$computer = Read-Host "Enter the computer name: "

$lastuser = (Get-ChildItem "\\$computer\c$\Users" | Sort-Object LastWriteTime -Descending | Select-Object Name,LastWriteTime -first 1)

$lastlogon = $lastuser.LastWriteTime

Get-AdUser -Identity $lastuser.Name | Select-Object Name,SamAccountName

Write-host "Last User logged into machine $computer at:`n------------------------------------------`n$lastlogon`n"