Import-Module ActiveDirectory

$ExportFilePath = "C:\temp\Inactiveusers2.csv"
$Report = @()
$Report += "samaccountname;name;whenCreated;lastlogondate"
$InactiveUsers = Get-ADUser -Filter * -Properties "whenCreated", "LastLogonDate" | sort-object -property Name | Where-Object { $_.Enabled -eq $true } 

ForEach ($InactiveUser in $InactiveUsers) {
	$InactiveUserInfo = $InactiveUser.samaccountname,$InactiveUser.name,$InactiveUser.whenCreated,$InactiveUser.lastlogondate -join ";"
	$Report += $InactiveUserInfo
}
$Report = $Report 
IF ($Report -ne "") {
	$report | Out-File $ExportFilePath 
}