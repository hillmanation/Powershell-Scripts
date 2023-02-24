$computers = Get-ADComputer -filter * -Properties Name,OperatingSystem -SearchBase "" -SearchScope Subtree | where { $_.OperatingSystem -like "*Windows Server*" -and $_.Name -notlike "*GOLD*" -and $_.Name -notlike "*template*" -and $_.Name -notlike "CIMSERVER*" -and $_.Name -notlike "DC0*" } | Select-Object Name,OperatingSystem
$logfile = "\_Hillman\Script Output\ServerInstalledRoles.csv"

ForEach ($computer in $computers) {

    If ($computer.OperatingSystem -like "*2008*") {
        
        $sesh = New-PSSession -computername $computer.Name -ErrorAction SilentlyContinue

        If (!($sesh)) { $computer = $computer.Name; Write-Warning "Unable to connect to $computer!!!" }
        Else {
                Invoke-Command -session $sesh -ScriptBlock { Import-Module servermanager; $output = Get-WindowsFeature -computername $Using:computer.Name | Where Installed | Select Name,DisplayName,Path

        ForEach ($line in $output) {
            $output2 = [pscustomobject]@{ ServerName=$Using:computer.Name; RoleName=$line.Name; DisplayName=$line.DisplayName; Path=$line.Path }
            $output2 | Export-CSV $logfile -NoTypeInformation -Append } }}}
    Else {
        $output = Get-WindowsFeature -computername $computer.Name | Where Installed | Select Name,DisplayName,Path

        ForEach ($line in $output) {
            $output2 = [pscustomobject]@{ ServerName=$computer.Name; RoleName=$line.Name; DisplayName=$line.DisplayName; Path=$line.Path }
            $output2 | Export-CSV $logfile -NoTypeInformation -Append  } }
}