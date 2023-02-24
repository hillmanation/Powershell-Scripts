Import-Module ActiveDirectory

## Get all Windows OS Computer Objects, minus the "GOLD" image objects and get todays date, define output variables
$computers = Get-ADComputer -filter * -Properties Name,OperatingSystem -SearchBase ",DC=COM" -SearchScope Subtree | where { $_.OperatingSystem -like "*Windows*" -and $_.Name -notlike "*GOLD*" } | Select-Object Name, OperatingSystem
$date = Get-Date -Format "_MM_dd_yyyy"
$blank,$month,$day,$year = $date.split("_")
$fullmonth = get-date -UFormat %B

## Check for year and month folder in Log folder and create folders if needed
---> $rootfolder = "\\Share\Folder_1\Folder_2\Compliance Reports\AV_Date_Reports\"
$yearFolder = $rootfolder + $year + "\"

If (!(Test-Path -Path $yearfolder)) { New-Item -Path $rootfolder -Name $year -ItemType Directory -Force | Out-Null }

$monthfolder = $month + " - " + $fullmonth
$outfolder = $yearfolder + "\" + $monthfolder + "\"

If (!(Test-Path -Path $outfolder)) { New-Item -Path $yearfolder -Name $monthfolder -ItemType Directory -Force | Out-Null }

$fileName = $outFolder + "Windows_AV_Def_Dates" + $date + ".csv"


##Get AV Def date for each computer from above
ForEach ($computer in $computers) {
    
    ## Test connection to computer to ensure it is reachable
    If (!(Test-Connection -computername $computer.Name -Count 2 -Quiet)) { $outfile = [pscustomobject]@{ ComputerName = $computer.Name; OperatingSystem = $computer.OperatingSystem; LastVirusDefsDate = "UNABLE TO CONNECT TO COMPUTER" }; $outfile | Export-CSV $fileName -NoTypeInformation -Append }

    Else {
        $remoteREG = $computer.Name

        ##Connect to remote registry and find the "LatestVirusDefsDate" value
        $type = [Microsoft.Win32.RegistryHive]::LocalMachine
        $regkey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($type, $remoteREG).OpenSubKey("SOFTWARE\Symantec\Symantec Endpoint Protection\CurrentVersion\Public-Opstate")
        $virusdate = $regkey.GetValue("LatestVirusDefsDate")

        ##Place the found info into a custom object for formatting into a CSV file
        If ($virusdate -ne $NULL) {
            $outfile = [pscustomobject]@{ ComputerName = $computer.Name; OperatingSystem = $computer.OperatingSystem; LastVirusDefsDate = $virusdate }

            $outfile | Export-CSV $fileName -NoTypeInformation -Append }
        else {$outfile = [pscustomobject]@{ ComputerName = $computer.Name; OperatingSystem = $computer.OperatingSystem; LastVirusDefsDate = "NO DATE FOUND" } ##If the key is not found output an error msg

              $outfile | Export-CSV $fileName -NoTypeInformation -Append }
    }
    ##Clean Up
    $remoteREG, $type, $regkey, $virusdate, $outfile = $NULL

}