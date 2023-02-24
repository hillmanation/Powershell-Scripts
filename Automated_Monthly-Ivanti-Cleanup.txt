import-module activedirectory

$computers = (Get-ADComputer -filter * -Properties OperatingSystem,DistinguishedName | where { $_.OperatingSystem -like "Windows*" -and $_.OperatingSystem -notlike "*Server*" -and $_.DistinguishedName -notlike "*Test Cell*" -and $_.Name -notlike "*GOLD*" -and $_.Name -notlike "*FTWS*" } | Sort-Object -Property Name).Name
$startDate = Get-Date
$date = Get-Date -Format "HH:mm MM-dd-yyyy"

## Check for year and month folder in Log folder and create folders if needed
$filedate = Get-Date -Format "_MM_dd_yyyy"
$blank,$month,$day,$year = $filedate.split("_")
$fullmonth = get-date -UFormat %B
---> $rootfolder = "\\Share\Folder_1\Folder_2\Monthly Ivanti Patch File Cleanup\"
$yearFolder = $rootfolder + $year + "\"

If (!(Test-Path -Path $yearfolder)) { New-Item -Path $rootfolder -Name $year -ItemType Directory -Force | Out-Null }

$fileNameLog = $rootfolder + $year + "\" + $month + "-" + $fullmonth + "-Ivant Patch Cleanup Log.txt"

"----Starting script to delete old package files from Computers at $date----" | Add-Content $fileNameLog

ForEach ($computer in $computers) {
    $folders = "\\$computer\c$\Windows\Options\Packages","\\$computer\c$\Windows\ProPatches\Patches"
    "`r`n----Deleting files from $computer----`r`n" | Add-Content $fileNameLog

    ForEach ($folder in $folders) {
    If (Test-Path $folder) { $folderNames = Get-ChildItem $folder | % { $_.Name } }
    Else { $folderNames = $NULL }
    If ($folderNames -ne $NULL) { ForEach ($folderName in $folderNames) { Remove-Item $folder\$folderName -recurse -Force; $now = Get-Date -Format "HH:mm MM-dd-yyyy"; "Removed item $folder\$folderName from $computer at $now" | Add-Content $fileNameLog }}
    Else { $now = Get-Date -Format "HH:mm MM-dd-yyyy"; "--NO $folder to remove exists on $computer moving to next folder $now--" | Add-Content $fileNameLog }
    }
}

$endTime = Get-Date
$elapsed = (($endTime - $Startdate).TotalSeconds)

"`r`n-----Script completed at $endTime in $elapsed seconds-----" | Add-Content $fileNameLog