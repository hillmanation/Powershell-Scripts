import-module activedirectory

$computers = (Get-ADComputer -Filter { OperatingSystem -Like '*Windows*' -and Name -notlike "*GOLD*" -and Name -notlike "D44*" } | Sort-Object -Property Name).Name
$output = @()

## Check for year and month folder in Log folder and create folders if needed
$filedate = Get-Date -Format "_MM_dd_yyyy"
$blank,$month,$day,$year = $filedate.split("_")
$fullmonth = get-date -UFormat %B
---> $rootfolder = "\\\Share\Folder_1\Folder_2\Weekly Drive Space Audit\"
##$yearFolder = $rootfolder + $year

<#If (!(Test-Path -Path $yearfolder)) { New-Item -Path $rootfolder -Name $year -ItemType Directory -Force | Out-Null }

$monthfolder = $month + " - " + $fullmonth
$outfolder = $yearfolder + "\" + $monthfolder + "\"

If (!(Test-Path -Path $outfolder)) { New-Item -Path $yearfolder -Name $monthfolder -ItemType Directory -Force | Out-Null }

$fileNameCSV = $outfolder + "DriveSpaceAudit" + $filedate + ".csv"#>

$filenameCSV = $rootfolder + "\DriveSpaceAudit.csv"

ForEach ($computer in $computers) {
    ##echo "Starting on $computer..."
    If (Test-Connection -ComputerName $computer -Count 1 -Quiet) {
        $os = Get-WMIObject win32_OperatingSystem -computername $computer -ErrorAction SilentlyContinue
        $properties = Get-WMIObject Win32_Logicaldisk -filter "deviceid='$($os.systemdrive)'" -ComputerName $computer -ErrorAction SilentlyContinue
        $drivename = $properties.DeviceID
        If ($properties -eq $NULL) { $drivename = "UNABLE TO CONNECT"<#; Write-Warning "Unable to connect to $computer!!!"#> }
        $output += [pscustomobject]@{ ComputerName=$computer; DriveName=$drivename; SizeGB=([math]::Round($properties.Size/1GB,2)); FreeGB=([math]::Round($properties.FreeSpace/1GB,2)) }
        ##echo "Logging info for $computer..."
    }
    Else { <#Write-Warning "Unable to connect to $computer!!!";#> $output += [pscustomobject]@{ ComputerName=$computer; DriveName="UNABLE TO CONNECT"; SizeGB="0"; FreeGB="0" } }
}

##echo "Tasks complete, writing to log file..."
$output | Export-CSV $fileNameCSV -NoTypeInformation
$output | Export-CSV "\Temp\Weekly Drive Space Audit\DriveSpaceAudit.csv" -NoTypeInformation
##echo "`n`nCOMPLETE!"

##$leave = Read-Host "Press any key to continue..."