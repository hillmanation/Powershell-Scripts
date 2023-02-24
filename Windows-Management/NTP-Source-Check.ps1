Import-module activedirectory

$computers = (Get-AdComputer -filter * -Properties Name,OperatingSystem | where { $_.OperatingSystem -like "*Windows*" } | Select-Object Name).Name
$incorrectsource = @()

ForEach ($computer in $computers) {
    
    $timesource = w32tm /query /computer:$computer /source

    If ($timesource -ne "" -or $timesource -ne "") { $incorrectsource += [pscustomobject]@{ Hostname=$computer; Timesource=$timesource } }
}