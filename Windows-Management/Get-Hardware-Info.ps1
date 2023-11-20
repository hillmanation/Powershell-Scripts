<#
.SYNOPSIS
Given a list of Windows hosts, return hardware information to console or CSV.

.DESCRIPTION

# Get-Hardware-Info.ps1
# Author: Jake Hillman <jake.hillman.it@gmail.com>
# Created: 2023-11-20

This script will query the provided computers for hardware information, it will output CPU, RAM, and Model information
either to the console or a CSV file. If you are not outputting to a CSV file you can pipe the information to Out-Gridview
(e.g. .\Get-Hardware-Info.ps1 -Computers localhost | Out-GridView) for easier viewing.

.PARAMETER ComputerName
Pass this parameter one or multiple computer names (e.g. Computer-1 or Computer-1,Computer-2,Computer-3)

.PARAMETER ComputerList
Pass this parameter a list of computers in a text file, do not include a header. (i.e. 'Computers' on the first line)
If should appear as follows:
Computer-1
Computer-2
Computer-3
...etc

.PARAMETER OU
Pass this parameter one or multiple Distinguished OUs to find computers from. (e.g. '-OU "OU=Computers,DC=contoso,DC=COM"' or
'-OU "OU=Computers,DC=contoso,DC=COM","OU=Workstations,DC=contoso,DC=COM"')
If you use this parameter the script must be run from a location where the Active Directory Powershell module is available.

.PARAMETER AllWorkstations
This parameter does not accept input, use this parameter to tell the script to locate a list of Windows Workstations from AD.
If you use this parameter the script must be run from a location where the Active Directory Powershell module is available.

.PARAMETER AllVIDs
This parameter does not accept input, use this parameter to tell the script to locate a list of Windows VDIs from AD.
If you use this parameter the script must be run from a location where the Active Directory Powershell module is available.

.PARAMETER Query
Pass this parameter one or more of the following: RAM, RAMUsage%, RAMUsage, CPU, CPUusage%, CPUusage, DiskInfo, Model. (i.e. '-Query CPU' or '-Query RAM,Model')
If you want the script to return all possible host hardware info, do not set this parameter.

Query Parameter info:
RAM: Returns amount of RAM available to the system
RAMUsage%: Returns the currently used percentage of available RAM
RAMUsage: Returns the top 5 processes consuming RAM and the amount in GB, separated by comma
CPU: Returns CPU model/family information
CPUusage%: Returns the current CPU usage percent
CPUusage: Returns the top 5 processes using the CPU and what percentage (This CAN be greater than 100% if the process is multithreaded), separated by comma
DiskInfo: Returns logical disk volume information and Bitlocker status, separated by comma for multiple disks
Model: Returns reported hardware model information
S/N: Returns reported hardware serial number
BIOSVer: Returns reported system BIOS version
TPM: Returns reported onboard TPM status

.PARAMETER CSV
Pass this parameter the full path and filename you want the CSV file to be output to. If you don't use this parameter, output location
will be set to the console.

.PARAMETER AsTask
This paremeter does not accept input, use this parameter to suppress script console output when running as a Scheduled Task. If you use
this parameter you must also define the CSV parameter. Any errors when using this parameter will be placed in a log file in
$PSScriptRoot (The directory the script was ran from).

.EXAMPLE
.\Get-Hardware-Info.ps1 -Computers Computer-1,Computer-2
Query all info from the given computers and then output the results to the console.

.EXAMPLE
.\Get-Hardware-Info.ps1 -ComputerList C:\temp\computers.txt -Query RAM,MODEL
Query the provided list of computers for only RAM size and MODEL name and output the results to the console.

.EXAMPLE
.\Get-Hardware-Info.ps1 -ComputerName Computer-1 -ComputerList C:\temp\computers.txt -OU "OU=Computers,DC=contoso,DC=COM" -CSV C:\temp\csv.csv -Query RAM,MODEL
Query the provided computers, list of computers, and OU for only RAM size and MODEL name and output the results to CSV.

.EXAMPLE
.\Get-Hardware-Info.ps1 | Out-GridView
Query the localhost for all possible information and then output the results to Out-GridView for easy viewing.

.EXAMPLE
.\Get-Hardware-Info.ps1 -AllWorkstations -CSV C:\temp\hardware-info.csv -AsTask
Query all info from all workstations in AD (Named either "WS-*" or "WKS-*"), send the output to a CSV named C:\temp\hardware-info.csv,
and suppress all console output.

.LINK
https://github.com/hillmanation/Powershell-Scripts/tree/main/Windows-Management/Get-Hardware-Info.ps1

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
[CmdletBinding(DefaultParameterSetName='Computers')]
param(
         [Parameter(
                HelpMessage = "Enter one or more computers",
                ParameterSetName = 'Computers'
        )]
        [Parameter(
                HelpMessage = "Enter one or more computers",
                ParameterSetName = 'AsTask'
        )] [string[]]$ComputerName,
        [Parameter(
                HelpMessage = "Enter a path to a text file list of computers",
                ParameterSetName = 'Computers'
        )] 
        [Parameter(
                HelpMessage = "Enter a path to a text file list of computers",
                ParameterSetName = 'AsTask'
        )] [string]$ComputerList,
        [Parameter(
                HelpMessage = "Enter one or more Distinguished OU names",
                ParameterSetName = 'Computers'
        )] 
        [Parameter(
                HelpMessage = "Enter one or more Distinguished OU names",
                ParameterSetName = 'AsTask'
        )] [string[]]$OU,
        [Parameter(
                HelpMessage = "Use this switch if you want to pull a list of all Workstations from AD",
                ParameterSetName = 'All'
        )] 
        [Parameter(
                HelpMessage = "Use this switch if you want to pull a list of all Workstations from AD",
                ParameterSetName = 'AsTask'
        )] [switch]$AllWorkstations,
        [Parameter(
                HelpMessage = "Use this switch if you want to pull a list of all VDIs from AD",
                ParameterSetName = 'All'
        )] 
        [Parameter(
                HelpMessage = "Use this switch if you want to pull a list of all VDIs from AD",
                ParameterSetName = 'AsTask'
        )] [switch]$AllVDIs,
        [Parameter(
                HelpMessage = "Enter your desired hardware query items"
        )] 
        [ValidateSet('RAM','RAMUsage','RAMUsage%','CPU','CPUusage%','CPUusage','DiskInfo','Model','S/N','BIOSVer','TPM')]
        [string[]]$Query = ("RAM","RAMUsage","RAMUsage%","CPU","CPUusage","CPUusage%","DiskInfo","Model","S/N","BIOSVer","TPM"),
        [Parameter(
                HelpMessage = "Set this parameter to your desired CSV output path and filename (e.g. C:\temp\hostinfo.csv).",
                ParameterSetName = 'Computers'
        )]
        [Parameter(
                HelpMessage = "Set this parameter to your desired CSV output path and filename (e.g. C:\temp\hostinfo.csv).",
                ParameterSetName = 'All'
        )]
        [Parameter(
                Mandatory = $true,
                HelpMessage = "Set this parameter to your desired CSV output path and filename (e.g. C:\temp\hostinfo.csv).",
                ParameterSetName = 'AsTask'
        )] [string]$CSV,
        [Parameter(
                Mandatory = $true,
                HelpMessage = "Use this switch to supress output when running as a scheduled task",
                ParameterSetName = 'AsTask'
        )] [switch]$AsTask
)

############################################
#####   Script Parameters Block End    #####
############################################

<# Enable strict mode to protect us against the evils of oopsied unset variables.
## It's the difference between rm c:\Windows\temp\$folder translating to C:\windows\temp
## or throwing an error if $folder is uninitialized.
## https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/set-strictmode?view=powershell-5.1 #>
Set-StrictMode -Version 3.0

############################################
######      Functions Block Begin     ######
############################################

function Write-ProgressHelper {
    param(
        [int]$StepNumber,
        [string]$Message,
        [int]$remaining
    )
    
    Write-Progress -Activity "Querying Machine Info" -CurrentOperation $Message -PercentComplete (($StepNumber / $total) * 100) -SecondsRemaining $remaining
}

############################################
######      Functions Block End       ######
############################################


############################################
######          Script Begin          ######
############################################

## This is a unique case I may have to look into later, but we only need the Active Directory Module
## if the 'AllWorkstations', 'AllVDIs', or 'OU' switch is used, so we'll only load it here if it's present
## so in lieu of Requiring the AD module, we'll just check if it's needed here and handle it
If ($AllWorkstations.IsPresent -or $AllVDIs.IsPresent -or $OU -ne $null) {
    Try { Import-Module ActiveDirectory -ErrorAction Stop }
    Catch { Write-Warning (@("'AllWorkstations', 'AllVDIs', or 'OU' selected and ActiveDirectory module not found. Run from a computer that has the ActiveDirectory"
            "Powershell module installed and try again.`nOr pass the script computers with '-ComputerName' or '-ComputerList' instead.") -join " "); Exit }
}

## Initialize variables, validate the argument input
$computers = @()
If ($AllWorkstations.IsPresent) { $computers += (Get-ADComputer -filter * -Properties Name,OperatingSystem | where { $_.OperatingSystem -like "*Windows*" -and $_.OperatingSystem -notlike "*Server*" -and $_.Name -like "WS-*" -or $_.Name -like "WKS-*" }).Name; $total = $computers.Count }
If ($AllVDIs.IsPresent) { $computers += (Get-ADComputer -filter * -Properties Name,OperatingSystem | where { $_.OperatingSystem -like "*Windows*" -and $_.OperatingSystem -notlike "*Server*" -and $_.Name -like "VDI-*" }).Name; $total = $computers.Count }
If ($OU -ne '' -and $OU -is [system.array] -or $OU -is [system.string]) { 
    ForEach ($DistName in $OU) { 
        Try { $computers += (Get-ADComputer -filter * -SearchBase $DistName -SearchScope Subtree | where { $_.OperatingSystem -like "*Windows*" -and $_.OperatingSystem -notlike "*Server*" }).Name
              $total = $computers.Count
        } Catch { Write-Warning "Invalid OU Distinguished Name provided, validate the OU and try again."; Exit }
    }
}
If ($ComputerName -ne '' -and $ComputerName -is [system.array] -or $ComputerName -is [system.string]) { $computers = $ComputerName; $total = $computers.Count }
If ($ComputerList -ne '' -and $ComputerList -is [system.string]) { 
    Try { If (!(Test-Path -Path $ComputerList -ErrorAction SilentlyContinue)) { Throw [System.IO.FileNotFoundException] } }
    Catch { Write-Warning "List file $ComputerList not found, please verify file path and location and try again."; Exit }

    $computers += Get-Content -Path $ComputerList -ErrorAction Inquire; $total = $computers.Count
}

## If no computers are passed default the $computer list to 'localhost'
If (!$computers) { 
    If (!$AsTask.IsPresent) {
        Write-Host -ForegroundColor Yellow "No Computer entered, defaulting to '" -NoNewline
        Write-Host -ForegroundColor Green "localhost" -NoNewline
        Write-Host -ForegroundColor Yellow "'..."
    }
    $computers = 'localhost'; $total = 1
}

## If 'CSV' is set, check the output directory exists, if it does not, or CSV is not set, set $CSV to current working directory
If ($CSV -ne '') {
    ## Let's loop this for validation
    Do {
        $validate = $false
        ## Verify the provided $CSV path argument is a valid reachable location
        Try { If (!(Test-Path -Path $(Split-Path $CSV -Parent) -ErrorAction SilentlyContinue)) { throw [System.IO.FileNotFoundException]::new() }
              Elseif ($CSV -notlike "*.csv") { throw [System.IO.FileFormatException]::new() }
              Else { $validate = $true } }
        Catch [System.IO.FileNotFoundException] { Write-Warning "Output directory '$CSV' not found, please verify file path and location..."
            Write-Host -ForegroundColor Yellow "Type Ctrl+C to exit or correct the path below."
            $check = Read-Host "Type the corrected path here, or hit 'Enter' to use the default name and path `n[$PSScriptRoot\Hardware-Info-Query_$(Get-Date -f "MM-dd-yy").csv]"
            If ($check -ne '') {
                Write-Host -ForegroundColor Green "CSV output path set to [$check]..."
                $CSV = $check
            }
            Else { 
                Write-Host -ForegroundColor Green "CSV output path set to [$PSScriptRoot\Hardware-Info-Query_$(Get-Date -f "MM-dd-yy").csv]..."
                $CSV = "$PSScriptRoot\Hardware-Info-Query_$(Get-Date -f "MM-dd-yy").csv"
            }
        }
        Catch [System.IO.FileFormatException] { Write-Warning "Invalid file extension '$CSV', please verify file path and extension is set to '.csv'..."
            Write-Host -ForegroundColor Yellow "Type Ctrl+C to exit or correct the filename below."
            $check = Read-Host "Type the corrected path here, or hit 'Enter' to use the default name `n[$(Split-Path $CSV -Parent)\Hardware-Info-Query_$(Get-Date -f "MM-dd-yy").csv]"
            If ($check -ne '') {
                Write-Host -ForegroundColor Green "CSV filename set to [$check]..."
                $CSV = "$(Split-Path $CSV -Parent)\$check"
            }
            Else { 
                Write-Host -ForegroundColor Green "CSV output path set to [$(Split-Path $CSV -Parent)\Hardware-Info-Query_$(Get-Date -f "MM-dd-yy").csv]..."
                $CSV = "$(Split-Path $CSV -Parent)\Hardware-Info-Query_$(Get-Date -f "MM-dd-yy").csv"
            }
        }
    } While ($validate -ne $true)
}

$failed = @()
$start = Get-Date
$progress = 0
$output = @()

## Start querying hardware information from the list of computers, but first let's alphabetize the list
$computers = $computers | Sort-Object
ForEach ($computer in $computers) {
    ## Set loop variables, mainly for tracking and updating the progress bar
    $progress++
    $elapsed = ("{0:hh\:mm\:ss}" -f [timespan]::FromSeconds(((Get-Date) - $start).TotalSeconds))
    If ($progress -ne 1) { $average = ((Get-Date) - $start).TotalSeconds/$progress }
    Else { $average = 25 }
    $timeremaining = ([timespan]::FromSeconds($average * ($total - $progress))).TotalSeconds

    If (!$AsTask.IsPresent -and $total -gt 1) { Write-ProgressHelper -StepNumber $progress -Message "Querying information from $computer...`tTotal Elapsed Time: $elapsed" -Remaining $timeremaining }

    ## Check the connection to the computer
    If (!$AsTask.IsPresent) { 
        Write-Host "`nChecking if " -NoNewLine 
        Write-Host "$computer" -ForegroundColor Green -NoNewline
        Write-Host " is reachable..."
    }
    If(!(Test-Connection -ComputerName $computer -Count 2 -Quiet -ErrorAction SilentlyContinue)) {
        If (!$AsTask.IsPresent) { Write-Warning "Unable to connect to $computer, logging and moving on..." }; $failed += [pscustomobject]@{ NAME=$computer; Reason="Offline"}; Continue }

    If (!$AsTask.IsPresent) { Write-Host "Successfully connected!" -ForegroundColor Green }

    ## Computer is up, but let's check WSMAN to verify that is endabled on the device for the CimInstance query
    If (!(Test-WSMan -ComputerName $computer -ErrorAction SilentlyContinue)) { If (!$AsTask.IsPresent) { Write-Warning "PSRemoting not enabled on $computer, attempting to enable it..." }
        ## Run a remote wmic command to tell the computer to enable winrm
        $script = 'wmic /node:"' + $computer + '" process call create "cmd.exe /c winrm quickconfig -quiet"'
        cmd.exe /c $script 2> $null
        ## Check to see if that worked
        If (Test-WSMan -ComputerName $computer -ErrorAction SilentlyContinue) {
            If (!$AsTask.IsPresent) { Write-Host -ForegroundColor Green "PSRemoting successfully enabled on $computer!!!" } }        
        Else { If (!$AsTask.IsPresent) { Write-Warning "PSRemoting unable to be enabled on $computer, logging and moving on..." }
            $failed += [pscustomobject]@{ ComputerName=$computer; Reason="WinRM not enabled" }; Continue }
    }

    ## Now let's grab the info we need from the remote machine, first establish a CimSession
    $CimSession = New-CimSession -ComputerName $computer

    If (!$AsTask.IsPresent) { Write-Host "Gathering requested information from $computer..." }

    ## Format info for CSV/Output
    $obj = [ordered]@{}
    $obj['COMPUTER'] = $computer
    ## Gather the RAM size
    If ('RAM' -in $Query) { $obj['RAM(GB)'] = (Get-CimInstance Win32_PhysicalMemory -CimSession $CimSession | Measure-Object -Property capacity -Sum).sum /1gb }
    ## Gather the RAM usage in %
    If ('RAMUsage%' -in $Query) { $obj['RAMUsage%'] = [Math]::Round((((Get-CimInstance -ClassName Win32_OperatingSystem -CimSession $CimSession).TotalVisibleMemorySize - (Get-CimInstance -ClassName Win32_OperatingSystem -CimSession $CimSession).FreePhysicalMemory) / (Get-CimInstance -ClassName Win32_OperatingSystem -CimSession $CimSession).TotalVisibleMemorySize * 100), 2) }
    ## Gather RAM Usage process Info
        If ('RAMUsage' -in $Query) { $RAMUsage = Get-Counter -ComputerName $computer -Counter "\Process(*)\Working Set" -SampleInterval 1 -MaxSamples 1 -ErrorAction SilentlyContinue | 
        Select-Object -ExpandProperty CounterSamples | 
        Where-Object { $_.InstanceName -ne "_Total" -and $_.InstanceName -ne "Idle" } | 
        Sort-Object -Property CookedValue -Descending | 
        Select-Object -First 5
        
        $n = 1 ## Setting this to determine if the value needs a comma
        ForEach ($usage in $RAMUsage) {
            If ($n -lt ($RAMUsage | Measure-Object).Count) { $comma = ", " } ## Place a comma if we aren't to the last value
            Else { $comma = "" }
            $obj['RAMUsage'] += [string]"$($usage.InstanceName)($([Math]::Round($usage.CookedValue / 1GB, 2)) GB)$comma"
            $n++
        }
    }
    ## Gather CPU Info
    If ('CPU' -in $Query) { $obj['CPU'] = (Get-CimInstance CIM_Processor -CimSession $CimSession)[0].Name }
    ## Gather CPU usage in %
    If ('CPUusage%' -in $Query) { $obj['CPUusage%'] = (Get-CimInstance -ClassName Win32_Processor -CimSession $CimSession).LoadPercentage }
    ## Gather CPU Usage process Info
    If ('CPUusage' -in $Query) { $cpuUsage = Get-Counter -ComputerName $computer -Counter "\Process(*)\% Processor Time" -SampleInterval 1 -MaxSamples 1 -ErrorAction SilentlyContinue | 
        Select-Object -ExpandProperty CounterSamples | 
        Where-Object { $_.InstanceName -ne "_Total" -and $_.InstanceName -ne "Idle" } | 
        Sort-Object -Property CookedValue -Descending | 
        Select-Object -First 5
        
        $n = 1 ## Setting this to determine if the value needs a comma
        ForEach ($usage in $cpuUsage) {
            If ($n -lt ($cpuUsage | Measure-Object).Count) { $comma = ", " } ## Place a comma if we aren't to the last value
            Else { $comma = "" }
            $obj['CPUusage'] += [string]"$($usage.InstanceName)($([Math]::Round($usage.CookedValue, 2))%)$comma"
            $n++
        }
    }
    ## Query local Disk info
    If ('DiskInfo' -in $Query) { $disks = Get-CimInstance Win32_LogicalDisk -CimSession $CimSession | where { $_.DriveType -eq "3" }
        $n = 1 ## Setting this to determine if the value needs a comma
        ForEach ($disk in $disks) {
            If ($n -lt ($disks | Measure-Object).Count) { $comma = ", " } ## Place a comma if we aren't to the last value
            Else { $comma = "" }
            $bdestatus = Get-CimInstance -ClassName "Win32_EncryptableVolume" -Namespace "Root\CIMV2\Security\MicrosoftVolumeEncryption" -CimSession $CimSession | where { $_.DriveLetter -eq $disk.DeviceID }
            $obj['DiskInfo'] += [string]"$($disk.DeviceID) Volume:$($disk.VolumeName) Bitlocker:$($bdestatus.IsVolumeInitializedForProtection) Size:$([Math]::Round($disk.Size / 1GB, 2))GB Used:$([Math]::Round((($disk.Size - $disk.FreeSpace) / 1GB), 2))GB$comma"
            $n++
        }
    }
    ## Gather Model info
    If ('MODEL' -in $Query) { $obj['MODEL'] = (Get-CimInstance Win32_ComputerSystem -CimSession $CimSession).Model }
    ## Gather S/N info
    If ('S/N' -in $Query) { $obj['S/N'] = (Get-CimInstance Win32_BIOS -CimSession $CimSession).SerialNumber }
    ## Gather BIOS Version info
    If ('BIOSVer' -in $Query) { $obj['BIOSVer'] = (Get-CimInstance Win32_BIOS -Property SMBIOSBIOSVersion -CimSession $CimSession).SMBIOSBIOSVersion }
    ## Gather TPM info
    If ('TPM' -in $Query) { If ((Get-CimInstance Win32_Tpm -namespace root\CIMV2\Security\MicrosoftTpm -CimSession $CimSession).IsEnabled_InitialValue -eq 'True') { $obj['TPM'] = "Enabled" }
                            Else { $obj['TPM'] = "Disabled" }
    }

    ## Convert info variable to pscustomobject
    $obj = [pscustomobject]$obj

    ## Dispose the CimSession just in case something fails
    Remove-CimSession -CimSession $CimSession

    If (!$AsTask.IsPresent) { Write-Host -ForegroundColor Green "Complete!" -NoNewline }
    If ($CSV -ne '') { If (!$AsTask.IsPresent) { Write-Host " Writing information to CSV..." }
        $obj | Export-CSV -Path $CSV -NoTypeInformation -Append
    }
    Else { $output += $obj }

    If (!$AsTask.IsPresent) { Write-Host -ForegroundColor Yellow "`nInfo gathered from $computer, moving to next machine...`n" }
}

## Dispose of any remaining CimSession for my sanity
Get-CimSession | Remove-CimSession

If ($failed -ne '' -and !$AsTask.IsPresent) { Write-Warning "The following computers had errors while gathering hardware information:"; $failed }
ElseIf ($failed -ne '') { $failed | Out-File "$PSScriptRoot\Hardware-Info-ERRORS-$(Get-Date -f "MM-dd-yy").txt" -Append }

If (!$AsTask.IsPresent) { 
    Write-Host "_________________________________________________________________________________________`n" -ForegroundColor Green
    Write-Host "All tasks completed on provided computers at " -ForegroundColor Yellow -NoNewline
    Write-Host "$(Get-Date -Format HH:mm:ss)" -ForegroundColor Green -NoNewLine
    Write-Host "...`n" -ForegroundColor Yellow
    Write-Host "Review any above warning text/error output for issues," -ForegroundColor Yellow
    If ($CSV -ne '') { Write-Host "navigate to " -ForegroundColor Yellow -NoNewline
                       Write-Host "$CSV" -ForegroundColor Green -NoNewline
                       Write-Host "`nto view the generated CSV file." -ForegroundColor Yellow
    }
    Else { Write-Host "if console output is selected it will appear below." -ForegroundColor Yellow }
    Write-Host "_________________________________________________________________________________________`n" -ForegroundColor Green
}

If ($CSV -eq '' -and !$AsTask.IsPresent) { return $output }