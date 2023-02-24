#############################
## Created By Jake Hillman ##
#############################

Import-Module ActiveDirectory
$adcomputers = Get-ADComputer -filter * -Properties Name,OperatingSystem

$server2016 = $adcomputers | where { $_.OperatingSystem -like "*Windows Server 2016*" } | Select-Object Name
$server2019 = $adcomputers | where { $_.OperatingSystem -like "*Windows Server 2019*" } | Select-Object Name
$server2008 = $adcomputers | where { $_.OperatingSystem -like "*Windows Server 2008*" } | Select-Object Name

$win10wks = $adcomputers | where { $_.OperatingSystem -like "*Windows 10*" -and $_.Name -notlike "*vdi*" } | Select-Object Name
$win7wks = $adcomputers | where { $_.OperatingSystem -like "*Windows 7*" -and $_.Name -notlike "*vdi*"  } | Select-Object Name
$win10vdi = $adcomputers | where { $_.OperatingSystem -like "*Windows 10*" -and $_.Name -like "*vdi*" } | Select-Object Name
$win7vdi = $adcomputers | where { $_.OperatingSystem -like "*Windows 7*" -and $_.Name -like "*vdi*" } | Select-Object Name

$esxi = $adcomputers | where { $_.Name -like "*ESXI*" } | Select-Object Name
$vcsa = $adcomputers | where { $_.Name -like "*VCSA*" } | Select-Object Name

$output = @()

$output = [pscustomobject]@{Server2016=($server2016 | Measure-Object).Count;Server2019=($server2019 | Measure-Object).Count;Server2008=($server2008 | Measure-Object).Count;Win10Workstations=($win10wks | Measure-Object).Count;Win10VDIs=($win10vdi | Measure-Object).Count;Win7Workstation=($win7wks | Measure-Object).Count;Win7VDIs=($win7vdi | Measure-Object).Count;ESXIHosts=($esxi | Measure-Object).Count;VCSA=($vcsa | Measure-Object).Count;Total=($adcomputers | Measure-Object).Count }

$output | FT -AutoSize