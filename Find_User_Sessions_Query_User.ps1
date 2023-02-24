$InputFile = "\...\Computers.txt"
Get-ADComputer -Filter { OperatingSystem -Like '*Windows*' } -Properties OperatingSystem | Select-Object -expandproperty Name | Out-File -FilePath $InputFile
$Computers = Get-Content -Path $InputFile
Foreach ($Computer in $Computers) 
{
echo $Computer; query user /server:$Computer | findstr your_account_name ; echo '################################'

}