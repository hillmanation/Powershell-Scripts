﻿import-module activedirectory

$filelist = Import-CSV "\\DG_Report_10.12.2021.csv"
$outputpath = "\\DG_Report_10.12.2021_Removed.csv"
$output =@()

ForEach ($item in $filelist) {
    $filepath = $item.DEST_FILE_DIRECTORY
    $filename = $filepath + $item.DEST_FILE_NAME
    $computer = $item.COMPUTER_NAME
    
    If ($filename -notlike "**") { $drive,$filename = $filename.Split(':'); $filename = "\\$computer\$drive`$$filename" }

    If (!(Test-Path -Path $filename -ErrorAction SilentlyContinue)) { echo "$filename not found, logging and moving on...."; $output += [pscustomobject]@{ ComputerName = $computer; FILE = $filename; Removed = 'TRUE' }; Continue }

    Remove-Item -Path $filename -Force  -Confirm:$false

    If (!(Test-Path -Path $filename -ErrorAction SilentlyContinue)) { echo "$filename removed, logging and moving on...."; $output += [pscustomobject]@{ ComputerName = $computer; FILE = $filename; Removed = 'TRUE' } }
    Else { Write-Warning "$filename NOT removed, logging and moving on..."; $output += [pscustomobject]@{ ComputerName = $computer; FILE = $filename; Removed = 'FALSE' } }

}

$output | Export-CSV -Path $outputpath -NoTypeInformation -Append