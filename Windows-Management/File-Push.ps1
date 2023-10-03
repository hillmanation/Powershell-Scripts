<#
.SYNOPSIS
Simple script to copy a file to a location on a list of computers.

.DESCRIPTION

# File-Push.ps1
# Author: Jacob Hillman <jacob.hillman@ge.com>
# Created: 2023-10-03

This script accepts input of a source file path and a source local destination to copy that file to a list of given computers.
Provide the script a single computer, list of computers, or path to a text file. See below for parameter options. All parameters
except the Destination path will also accept UNC paths.

The script requires you to pass it SourceFile, Destination, and ONLY allows one of the following parameters:
Computers, ComputerList, or AllWorkstations

To run this script, run Powershell as Admin, change directory to the one the script is saved in (i.e. 'cd C:\User\SSO\Documents'),
then run it according to the examples below.

.PARAMETER SourceFile
Pass this parameter the path to the file you are trying to copy out to other machines.

.PARAMETER Destination
Pass this parameter the path to the directory on the remote hosts you want to copy the file to.

.PARAMETER Computers
Pass this parameter a singe computer name or a comma separated list of computer names.
(i.e. Computer-1 or Computer-1,Computer-2,Computer-3)

.PARAMETER ComputerList
Pass this parameter the path to a list of computers in a text file, do not include a header. (i.e. 'Computers' on the first line)
If should appear as follows:
Computer-1
Computer-2
Computer-3
...etc

.PARAMETER AllWorkstations
This parameter does not accept input, use this parameter to tell the script to locate a list of Windows Workstations from AD.
If you use this parameter the script must be run from a location where the Active Directory Powershell module is available.

.EXAMPLE
'.\File-Push.ps1' -SourceFile C:\Temp\file.txt -Destination C:\Temp\Folder -Computers Computer-1

.EXAMPLE
'.\File-Push.ps1' -SourceFile C:\Temp\file.txt -Destination C:\Temp\Folder -Computers Computer-1,Computer-2,Computer-3

.EXAMPLE
'.\File-Push.ps1' -SourceFile C:\Temp\file.txt -Destination C:\Temp\Folder -ComputerList C:\Temp\Computers.txt

.EXAMPLE
'.\File-Push.ps1' -SourceFile \\Share1\Ourstuff\file.txt -Destination C:\Temp\Folder -AllWorkstations

.LINK
https://github.build.ge.com/EdisonWorks-BAR/Useful-Powershell-Scripts/tree/main/General-Windows-Management\File-Push.ps1

#>

############################################
## REQUIRES and Import-Module Block Begin ##
## Include any REQUIRED modules, versions,##
##      or RunAsAdministrator below       ##
############################################

# See also: about_Requires
# https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_requires?view=powershell-5.1
#Requires -RunAsAdministrator

############################################
##  REQUIRES and Import-Module Block End  ##
############################################

############################################
#####  Script Parameters Block Begin   #####
############################################

param(
        [Parameter(
                Mandatory,
                HelpMessage = "Enter the Source File location or UNC path",
                ParameterSetName = 'List',
                Position=0
        )]
        [Parameter(
                Mandatory,
                HelpMessage = "Enter the Source File location or UNC path",
                ParameterSetName = 'AD',
                Position=0
        )]
        [Parameter(
                Mandatory,
                HelpMessage = "Enter the Source File location or UNC path",
                ParameterSetName = 'TextList',
                Position=0
        )] [string]$SourceFile,
        [Parameter(
                Mandatory,
                HelpMessage = "Enter the local location the file should be copied to on each computer",
                ParameterSetName = 'List'
        )]
        [Parameter(
                Mandatory,
                HelpMessage = "Enter the Source File location or UNC path",
                ParameterSetName = 'AD',
                Position=0
        )]
        [Parameter(
                Mandatory,
                HelpMessage = "Enter the Source File location or UNC path",
                ParameterSetName = 'TextList',
                Position=0
        )] [string]$Destination,
        [Parameter(
                HelpMessage = "Enter one or more computers, or a path to a text file list of computers",
                ParameterSetName = 'List'
        )] [string[]]$Computers,
        [Parameter(
                HelpMessage = "Enter one or more computers, or a path to a text file list of computers",
                ParameterSetName = 'TextList'
        )] [string]$ComputerList,
        [Parameter(
                HelpMessage = "Use this switch if you want to pull a list of all Workstations from AD instead of providing a list",
                ParameterSetName = 'AD'
        )] [switch]$AllWorkstations
)

############################################
#####   Script Parameters Block End    #####
############################################

## Enable strict mode to protect us against the evils of oopsied unset variables.
## It's the difference between rm c:\Windows\temp\$folder translating to C:\windows\temp
## or throwing an error if $folder is uninitialized.
## https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/set-strictmode?view=powershell-5.1
Set-StrictMode -Version 3.0

############################################
######      Functions Block Begin     ######
############################################

function Write-ProgressHelper {
    param(
        [int]$StepNumber,
        [string]$Message,
        [int]$remaining,
        [string]$filename
    )
    
    Write-Progress -Activity "Copying File $filename" -CurrentOperation $Message -PercentComplete (($StepNumber / $total) * 100) -SecondsRemaining $remaining
}

############################################
######      Functions Block End       ######
############################################


############################################
######          Script Begin          ######
############################################

## This is a unique case I may have to look into later, but we only need the Active Directory Module
## if the 'AllWorkstations' switch is used, so we'll only load it here if it's present
If ($AllWorkstations.IsPresent) {
Try { Import-Module ActiveDirectory -ErrorAction Stop }
Catch { Write-Warning "'AllWorkstations' selected and ActiveDirectory module not found. Run from a computer that has the ActiveDirectory Powershell module installed and try again.`nOr remove the '-AllWorkstations' switch and pass the script a list of computers with '-ComputerList' instead."; Exit }
}

## Initialize variables, validate the $ComputerList argument input
If ($AllWorkstations.IsPresent) { $computers = (Get-ADComputer -filter * -Properties Name,OperatingSystem | where { $_.OperatingSystem -like "*Windows*" -and $_.OperatingSystem -notlike "*Server*" -and $_.Name -like "WS-*" -or $_.Name -like "WKS-*" }).Name; $total = $computers.Count }
ElseIf ($Computers -ne '' -and $Computers -is [system.array]) { $total = $computers.Count }
ElseIf ($Computers -ne '' -and $Computers -is [system.string]) { $total = 1 }
ElseIf ($ComputerList -ne '' -and $ComputerList -is [system.string]) { 
    Try { If (!(Test-Path -Path $ComputerList -ErrorAction SilentlyContinue)) { Throw [System.IO.FileNotFoundException] } }
    Catch { Write-Warning "List file $ComputerList not found, please verify file path and location and try again."; Exit }

    $computers = Get-Content -Path $ComputerList -ErrorAction Inquire; $total = $computers.Count
}
Else { Write-Warning "Invalid Computer List provided, verify file path if used or review 'Get-Help .\File-Push.ps1 -Full' for parameter instructions."; Exit }
$failed = @()
$start = Get-Date
$progress = 0

## Verify the provided source file argument is a valid reachable location
Try { If (!(Test-Path -Path $SourceFile -ErrorAction SilentlyContinue)) { Throw [System.IO.FileNotFoundException] }
    ## Capture the file name from the successful path
    $SourceFileName = (Get-Item -Path $SourceFile).Name
}
Catch { Write-Warning "Source file $SourceFile not found, please verify file path and location and try again."; Exit }

## Start pushing out the file to the list of computers
ForEach ($computer in $computers) {
    ## Set loop variables, mainly for tracking and updating the progress bar
    $progress++
    $elapsed = ("{0:hh\:mm\:ss}" -f [timespan]::FromSeconds(((Get-Date) - $start).TotalSeconds))
    $average = ((Get-Date) - $start).TotalSeconds/$progress
    $timeremaining = ([timespan]::FromSeconds($average * ($total - $progress))).TotalSeconds

    Write-ProgressHelper -filename $SourceFileName -StepNumber $progress -Message "Running tasks on $computer...`tTotal Elapsed Time: $elapsed" -Remaining $timeremaining

    ## Check the connection to the computer
    Write-Host "Checking if $computer is reachable..."
    If(!(Test-Connection -ComputerName $computer -Count 2 -Quiet -ErrorAction SilentlyContinue)) {
        Write-Warning "Unable to connect to $computer, logging and moving on..."; $failed += [pscustomobject]@{ NAME=$computer; Reason="Offline"}; Continue }

    Write-Host "Successfully connected!" -ForegroundColor Green

    ## Check for destination path on the remote computer
    Write-Host "Checking if $Destination exists on $computer..."
    If(!(Test-Path -Path "\\$computer\$(($Destination.Replace('C:','c$')).Replace('D:','d$'))" -ErrorAction SilentlyContinue)) { 
        Write-Warning "Destination directory ($Destination) does not exist on $computer...`nLogging and moving on..."; $failed += [pscustomobject]@{ NAME=$computer; Reason="Destination Directory Unavailable"}; Continue }
    
    ## Copy the file to the computer
    Write-Host "Copying $SourceFile to $Destination on $computer..."
    Copy-Item -Path $SourceFile -Destination "\\$computer\$(($Destination.Replace('C:','c$')).Replace('D:','d$'))"

    ## Verify the copy operation was successful
    Write-Host "Checking if $SourceFile exists on $computer..."
    If(!(Test-Path -Path "\\$computer\$(($Destination.Replace('C:','c$')).Replace('D:','d$'))\$SourceFileName" -ErrorAction SilentlyContinue)) { 
        Write-Warning "$SourceFileName failed to copy to $computer...`nLogging and moving on..."; $failed += [pscustomobject]@{ NAME=$computer; Reason="Copy Failed"}; Continue }

    Write-Host "Copy operation completed on $computer, moving to next host..." -ForegroundColor Green
}

Write-Host "_________________________________________________________________________________________`n" -ForegroundColor Green
Write-Host "All tasks completed on provided computers at $(Get-Date -Format HH:mm:ss)...`n" -ForegroundColor Yellow
Write-Host "Review any above warning text/error output for issues." -ForegroundColor Yellow
Write-Host "_________________________________________________________________________________________`n" -ForegroundColor Green

If ($failed -ne '') { Write-Warning "The following computers had errors cleaning up the Registry values:"; $failed }