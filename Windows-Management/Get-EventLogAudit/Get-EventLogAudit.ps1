<#
.SYNOPSIS
Audit Windows Event Logs for Local or Remote computers and compile them into a CSV.

.DESCRIPTION

# Get-EventLogAudit.ps1
# Author: Jake Hillman <jacob.hillman@ge.com>
# Co-Author: Danny Kimble <daniel.kimble@ge.com>
# Created: 2024-06-10
# Version: 1.0

Given the local computer or a list of remote computers, gather event log data for a standard list of event logs,
a given list of event logs, with the abilty to only output logs from a specified date period.

If no parameters are provided the script will run in an interactive format with a few menus.

To run this script, run the Powershell console 'AS ADMIN' and navigate to the directory the script is saved in.
Run the script as shown in the examples.

This script is functional with the built in 'Get-Help' command:
Get-Help | .\Get-EventLogAudit.ps1
Get-Help -Full | .\Get-EventLogAudit.ps1

.PARAMETER Local
Using this switch will only run the audit on the local machine. This is the default parameter if nothing is passed to the script it
will assume you are only intending to run it on the local machine.

.PARAMETER Standalone
Using this switch will prompt you to provide credentials to login to remote machines. For use in standalone rooms.
You must specify at least a ComputerName or ComputerList variable if using this parameter.

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

.PARAMETER AllServers
This parameter does not accept input, use this parameter to tell the script to locate a list of Windows Servers from AD.
If you use this parameter the script must be run from a location where the Active Directory Powershell module is available.

.PARAMETER AllVDIs
This parameter does not accept input, use this parameter to tell the script to locate a list of Windows VDIs from AD.
If you use this parameter the script must be run from a location where the Active Directory Powershell module is available.

.PARAMETER All
This parameter does not accept input, use this parameter to tell the script that you want to enable 'AllWorkstations', 'AllServers', and 'AllVDIs'
switches.

.PARAMETER CSV
Pass this parameter the full path and filename you want the CSV file to be output to. If you don't use this parameter, output location
will be set to $PSScriptRoot (The directory the script was ran from).

.PARAMETER Quiet
Run the script with limited console output, essentially making the script non-interactive. (Some output is necessary for credential gathering.)

.PARAMETER Defaults
Ignore user settings saved in user profile.

.EXAMPLE
.\Get-EventLogAudit.ps1
This will run the script on the local machine interactively, defaulting the CSV name and output directory to the current directory in the console.

.EXAMPLE
.\Get-EventLogAudit.ps1 -Local -CSV C:\Temp\Event-Log-Audit.csv
This will run the script interactively only on the local machine, outputting to the given CSV path.

.EXAMPLE
.\Get-EventLogAudit.ps1 -ComputerName Computer-1,Computer-2 -CSV C:\Temp\Event-Log-Audit.csv
This will run the script interactively on the specified computers and CSV path.

.EXAMPLE
.\Get-EventLogAudit.ps1 -ComputerName Computer-1,Computer-2 -CSV C:\Temp\Event-Log-Audit.csv -Standalone
This will run the script interactively on the specified computers and CSV path, except you will be prompted for credentials for each computer,
for use in standalone environments

.EXAMPLE
.\Get-EventLogAudit.ps1 -ComputerList C:\Temp\computers.txt
Run the script interactively with a list of computer in a text file.

.\Get-EventLogAudit.ps1 -OU "OU=Computers,DC=Contoso,DC=COM","OU=Servers,DC=Contoso,DC=COM"
Run the script and gather windows machines from a single or multiple OU's from the local Active Directory domain.

.\Get-EventLogAudit.ps1 -AllWorkstations
Run the script against a list of workstations gathered from the local Active Directory domain.

.EXAMPLE
.\Get-EventLogAudit.ps1 -Local -Quiet
When using the Quiet switch, the default CSV output value will be used, if the user has saved audit settings in their profile,
the script will load those event IDs to query for the given machines, otherwise a default set of queries will be used.
This essentially makes the script non-interactive unless '-Standalone' is used, in which case credentials will be prompted.

.EXAMPLE
.\Get-EventLogAudit.ps1 -Local -Defaults
The '-Defaults' switch bypasses any user saved settings and will load the default set of event ID queries.

# Include a short description of the function being completed here
# Place the example command on the first line under '.EXAMPLE', the 'PS>' part will be automatically added

.LINK
https://github.build.ge.com/EdisonWorks-BAR/Useful-Powershell-Scripts/tree/main/General-Windows-Management/Get-EventLogAudit/Get-EventLogAudit.ps1

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
[CmdletBinding(DefaultParameterSetName='Local')]
param(
        [Parameter(
                HelpMessage = "Run only on the Local Machine",
                ParameterSetName = 'Local'
        )] [Alias("LocalHost","Me")]
           [switch]$Local,
        [Parameter(
                Mandatory=$true,
                HelpMessage = "Switch for using with Standalone computers that have networking so the script can be run from a single machine, this will prompt for Credentials",
                ParameterSetName = 'Standalone'
        )] [Alias("Labs","TestCells")]
           [switch]$Standalone,
        [Parameter(
                HelpMessage = "Enter one or more computers"
        )]  [string[]]$ComputerName,
        [Parameter(
                HelpMessage = "Enter a path to a text file list of computers"
        )] [string]$ComputerList,
        [Parameter(
                HelpMessage = "Enter one or more Distinguished OU names",
                ParameterSetName = 'Computers'
        )] [string[]]$OU,
        [Parameter(
                HelpMessage = "Use this switch if you want to pull a list of all Workstations from AD",
                ParameterSetName = 'All'
        )] [switch]$AllWorkstations,
        [Parameter(
                HelpMessage = "Use this switch if you want to pull a list of all Windows servers from AD",
                ParameterSetName = 'All'
        )] [switch]$AllServers,
        [Parameter(
                HelpMessage = "Use this switch if you want to pull a list of all VDIs from AD",
                ParameterSetName = 'All'
        )] [switch]$AllVDIs,
        [Parameter(
                HelpMessage = "Use this switch if you want to pull a list of all Windows machines from AD",
                ParameterSetName = 'All'
        )] [switch]$All,
        [Parameter(
                HelpMessage = "Set this parameter to your desired CSV output path and filename (e.g. C:\temp\hostinfo.csv)."
        )] [string]$CSV,
        [Parameter(
            HelpMessage = "Run script with no console output"
        )] [Alias("Q","S")]
           [switch]$Quiet,
        [Parameter(
            HelpMessage = "Run script with defaults"
        )] [switch]$Defaults
)

# If 'Standalone' switch is used, ensure either 'ComputerName' or 'ComputerList' is provided
if ($Standalone -and -not ($PSBoundParameters.ContainsKey('ComputerName') -or $PSBoundParameters.ContainsKey('ComputerList'))) {
    Write-Warning "When using the Standalone switch, you must specify either 'ComputerName' or 'ComputerList'."
    exit
}

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

function Set-DefaultSelections {
    ## Below are the Event IDs and Categories that will be used in the standard Audit
    ## output of the script, edit the below as needed, add/remove categories and IDs or
    ## comment out lines as needed as shown in the bottom example, after making changes
    ## SAVE the script file prior to running it
    $defaultCategories = @{
    ####--> DO NOT EDIT ABOVE THIS LINE <---####
        'Authentication Events'       = @{LogName = 'Security'; EventIDs = 4624,4625,4634; Enabled = $true}
        'File Events'                 = @{LogName = 'Security'; EventIDs = 4663,4660,4656,4670,4674; Enabled = $false}
        'Device Access Events'        = @{LogName = 'Security'; EventIDs = 4663,4656; Enabled = $true}
        'User Group Management Events'= @{LogName = 'Security'; EventIDs = 4720,4726,4738,4725,4740,4727,4730,4735; Enabled = $true}
        'Privileged Events'           = @{LogName = 'Security'; EventIDs = 4672,4719,4902,4713,4670,4656; Enabled = $true}
        'Admin Access Events'         = @{LogName = 'Security'; EventIDs = 4672,4625,4624,4648; Enabled = $true}
        'Role Escalation Events'      = @{LogName = 'Security'; EventIDs = 4672,4625; Enabled = $true}
        'Audit Log Access Events'     = @{LogName = 'Security'; EventIDs = 4663,4660,4656; Enabled = $true}
        'System Events'               = @{LogName = 'System'; EventIDs = 1074,1076,6005,6006,6008; Enabled = $true}
        'Printing Events'             = @{LogName = 'Microsoft-Windows-PrintService/Operational'; EventIDs = 307,308; Enabled = $false}
        'Application Events'          = @{LogName = 'Application'; EventIDs = 1000,1001; Enabled = $false}
    ####--> DO NOT EDIT BELOW THIS LINE <---####
        # 'EXAMPLE EVENTS'            = @{LogName = 'LogName'; EventIDs = 0000,0001; Enabled = $true} <----KEEP THIS Commented out
    }
    return $defaultCategories
}

## Let's build a menu for selecting and editing the categories and what EventIDs each of them audit
function Show-Selection {
    param([switch]$verbose, [switch]$info, $showCategories)

    ## Show the currently selected logs to be queried
    If (!$info) { cls; Write-Host "The below categories of audit logs are selected:`n" }
    $number = 1
    $showCategories = $showCategories.GetEnumerator() | Sort-Object -Property key

    ForEach ($category in $showCategories.GetEnumerator()) {
        $selected = $NULL
        $color = $NULL
        If ($category.Value.Enabled -eq $true) { $selected = 'x'; $color = 'Green' }
        Else { $selected = ' '; $color = 'Gray' }

        Write-Host -ForegroundColor $color "`t[$selected] $number. $($category.Name)"
        If ($verbose) {
            Write-Host -ForegroundColor $color "`t`t$($category.Value.LogName): $($category.Value.EventIDs)"
        }
        $number++
    }
    If (!$info) {
        $selection = Read-Host "`nPress Enter to confirm, enter a number to enable/disable that value,enter 'a' to enable all, 'd' to disable all, `nenter 'v' to show details, enter 'e' to edit a value, or 'r' to reset selections to default"

        ## Try to convert the selection to an integer
        [int]$selectionAsInt = 0
        $isNumber = [int]::TryParse($selection, [ref]$selectionAsInt)

        ## If the selection is a valid number within range, toggle the 'Enabled' value
        If ($isNumber -and $selectionAsInt -le $showCategories.Count -and $selectionAsInt -gt 0) {
            ## Get the key name based on the number
            $key = $selectionAsInt - 1
            ## Toggle the 'Enabled' value
            $showCategories[$key].Value.Enabled = -not $showCategories[$key].Value.Enabled
            If ($verbose) { Show-Selection -showCategories $showCategories -verbose }
            Else { Show-Selection -showCategories $showCategories}
        }
        ElseIf ($selection.tolower() -eq 'e') {
            $edit = Read-Host "Item to edit"

            ## Try to convert the selection to an integer
            [int]$editAsInt = 0
            $isNumber = [int]::TryParse($edit, [ref]$editAsInt)

            If ($isNumber -and $editAsInt -le $showCategories.Count -and $editAsInt -gt 0) {
                $key = $editAsInt - 1
                $editlogname = Read-Host "Change Log name/type? [$($showCategories[$key].Value.LogName)]"
                
                If ($editlogname -ne '') { $showCategories[$key].Value.LogName = $editlogname; Show-Selection -showCategories $showCategories -info -verbose }
                $editeventids = Read-Host "Change Event IDs? [$($showCategories[$key].Value.EventIDs)]"

                If ($editeventids -ne '') { $showCategories[$key].Value.EventIDs = $editeventids -split ','# | ForEach-Object { [int]$_ }
                    Show-Selection -showCategories $showCategories -verbose
                }
                Else { Show-Selection -showCategories $showCategories -verbose }
            }
            Else { Show-Selection -showCategories $showCategories }
        }
        ElseIf ($selection.tolower() -eq 'v') {
            Show-Selection -showCategories $showCategories -verbose
        }
        ElseIf ($selection.tolower() -eq 'a') {
            $showCategories.GetEnumerator() | ForEach-Object { $_.Value['Enabled'] = $true }
            If ($verbose) { Show-Selection -showCategories $showCategories -verbose }
            Else { Show-Selection -showCategories $showCategories }
        }
        ElseIf ($selection.tolower() -eq 'd') {
            $showCategories.GetEnumerator() | ForEach-Object { $_.Value['Enabled'] = $false }
            If ($verbose) { Show-Selection -showCategories $showCategories -verbose }
            Else { Show-Selection -showCategories $showCategories }
        }
        ElseIf ($selection.tolower() -eq 'r') {
            $confirm = Read-Host "Are you sure? This will also remove local user settings. Y/N"
            If ($confirm.tolower() -eq 'y') { 
                Delete-Settings; $showCategories = Set-DefaultSelections
                $showCategories = $showCategories.GetEnumerator() | Sort-Object -Property key
            }
            If ($verbose) { Show-Selection -showCategories $showCategories -verbose }
            Else { Show-Selection -showCategories $showCategories}
        }
        ElseIf ($selection -eq '') {
            If ($true -notin $showCategories.Value.Enabled) {
                Write-Warning "You must enable at least one category!"
                Start-Sleep 2
                If ($verbose) { Show-Selection -showCategories $showCategories -verbose }
                Else { Show-Selection -showCategories $showCategories}
            }
            Else { Write-Host "Selections confirmed!"
                $save = Read-Host "Save the above settings to User config file? Y/N"
                If ($save.tolower() -eq 'y') { Save-Settings -selected $showCategories; Start-Sleep 1 }
                cls
                return $showCategories
            }
        }
        Else {
            If ($verbose) { Show-Selection -showCategories $showCategories -verbose }
            Else { Show-Selection -showCategories $showCategories}
        }
    }
}

function Save-Settings {
    param($selected)
    Write-Host "Saving User settings..."
    $selected | ConvertTo-Json | Set-Content -Path $settings_file -Force
    Write-Host -ForegroundColor Green "Complete!"
}

function Delete-Settings {
    Write-Host "Removing User settings..."
    Remove-Item -Path $settings_file -force -ErrorAction SilentlyContinue
    Write-Host -ForegroundColor Green "Complete!"
}

function ConvertPSObjectToHashtable
{
    param (
        [Parameter(ValueFromPipeline)]
        $InputObject
    )

    process
    {
        if ($null -eq $InputObject) { return $null }

        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string])
        {
            $collection = @(
                foreach ($object in $InputObject) { ConvertPSObjectToHashtable $object }
            )

            Write-Output -NoEnumerate $collection
        }
        elseif ($InputObject -is [psobject])
        {
            $hash = @{}

            foreach ($property in $InputObject.PSObject.Properties)
            {
                $hash[$property.Name] = ConvertPSObjectToHashtable $property.Value
            }

            $hash
        }
        else
        {
            $InputObject
        }
    }
}

function Write-ProgressHelper {
    param(
        [int]$StepNumber,
        [string]$Activity,
        [string]$Message,
        [int]$remaining,
        [int]$totalSteps,
        [int]$id,
        [int]$parentid
    )
    
    Write-Progress -id $id -parentid $parentid -Activity $Activity -CurrentOperation $Message -PercentComplete (($StepNumber / $totalSteps) * 100) -SecondsRemaining $remaining
}

# Define a function to query event logs based on event IDs and log name
function Get-EventLogData {
    param (
        [string]$LogName,
        [string]$EventIDs,
        [string]$ComputerName,
        [pscredential]$Credential
    )
    ## Handle if a ComputerName is not provided
    If (-not $ComputerName) { $ComputerName = 'localhost' }

    ## Convert the EventIDs string to an array of integers
    $EventIDArray = $EventIDs.Split(',') | ForEach-Object { [int]$_ }
    $output = @()

    try {
        $params = @{
            ComputerName   = $ComputerName
            FilterHashtable = @{LogName = $LogName; Id = $EventIDArray}
            ErrorAction    = 'Stop'
        }
        
        If ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Credential')) {
            $params.Credential = $Credential
        }
        $output += Get-WinEvent @params | Select-Object -Property TimeCreated, Id, LevelDisplayName, Message
    } catch {
        if ($Error[0].FullyQualifiedErrorId -like "*NoMatchingEventsFound*") {
            Continue
        } else {
            Write-Host "An unexpected error occurred: $($Error[0].Exception.Message)"
            Continue
        }
    }
    return $output
}

# Define a function to gather credentials for a list of standalone machines
function Get-StandaloneCredential {
    param ([string[]]$machines)

    $credentials = @()

    ForEach ($machine in $machines) {
        Write-Host -ForegroundColor Yellow "Gathering credentials for $machine..."
    
        $machinecreds = Get-Credential -Message "Enter login for $machine" -UserName $env:USERNAME

        Write-Host "Testing Credentials for $machine..."

        ## Attempt to test the password on the remote machine to verify the credentials
        Try {
            $session = New-PSSession -ComputerName $machine -Credential $machinecreds -ErrorAction Stop
            Remove-PSSession $session
            Write-Host -ForegroundColor Green "Verified!`n`nMoving to next computer..."
        }
        Catch {
            Write-Warning "Failed to authenticate with provided credentials on $machine..."
            $retry = Read-Host "Would you like to retry? (Y/N)"
            if ($retry.tolower() -eq 'y') {
                ## Recursively call the function to retry entering credentials
                $machinecreds = return Get-StandaloneCredential -machines $machine
            }
            else {
                Write-Host "Skipping $machine..."
                continue
            }
        }
        
        $credentials += [pscustomobject]@{ ComputerName=$machine; USERNAME=$machinecreds.UserName; PASSWORD=$machinecreds.Password }
    }
    return $credentials
}

############################################
######      Functions Block End       ######
############################################

############################################
######          Script Begin          ######
############################################

## Handle the 'All' switch by setting related switches to true
If ($All) {
    $AllWorkstations = $true
    $AllServers = $true
    $AllVDIs = $true
}

## This is a unique case I may have to look into later, but we only need the Active Directory Module
## if the 'AllWorkstations', 'AllServers', 'AllVDIs', 'All', or 'OU' switch is used, so we'll only load it here if
## those are present in lieu of Requiring the AD module (which would make the script fail to run even if you
## didn't need it), we'll just check if it's needed here and handle it
## Load the Active Directory module only if necessary
$adModuleNeeded = $AllWorkstations -or $AllServers -or $AllVDIs -or $OU
If ($adModuleNeeded) {
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
    }
    catch {
        $errorMessage = @"
'AllWorkstations', 'AllServers', 'AllVDIs', 'All', or 'OU' selected and ActiveDirectory module not found.
Run from a computer that has the ActiveDirectory PowerShell module installed and try again.
Or pass the script computers with '-ComputerName' or '-ComputerList' instead.
"@
        Write-Warning $errorMessage
        exit
    }
}

## Initialize variables
$computers = @()
## Get list of workstations
If ($AllWorkstations) {
    $computers += Get-ADComputer -Filter * -Properties Name, OperatingSystem | Where-Object { 
        $_.OperatingSystem -like "*Windows*" -and 
        $_.OperatingSystem -notlike "*Server*" -and
        $_.Name -notin $computers -and
        ($_.Name -like "WS-*" -or $_.Name -like "WKS-*")
    } | Select-Object -ExpandProperty Name
}
## Get list of servers
If ($AllServers) {
    $computers += Get-ADComputer -Filter * -Properties Name, OperatingSystem | Where-Object { 
        $_.OperatingSystem -like "*Windows*" -and 
        $_.OperatingSystem -like "*Server*" -and
        $_.Name -notin $computers
    } | Select-Object -ExpandProperty Name
}
## Get list of VDIs
If ($AllVDIs) {
    $computers += Get-ADComputer -Filter * -Properties Name, OperatingSystem | Where-Object { 
        $_.OperatingSystem -like "*Windows*" -and 
        $_.OperatingSystem -notlike "*Server*" -and
        $_.Name -notin $computers -and
        $_.Name -like "VDI-*" 
    } | Select-Object -ExpandProperty Name
}
## Get computers from specified OUs
If ($OU) {
    foreach ($DistName in $OU) {
        try {
            $computers += Get-ADComputer -Filter * -Properties Name, OperatingSystem -SearchBase $DistName -SearchScope Subtree | Where-Object { 
                $_.OperatingSystem -like "*Windows*" -and 
                $_.OperatingSystem -notlike "*Server*" -and
                $_.Name -notin $computers
            } | Select-Object -ExpandProperty Name
        } catch {
            Write-Warning "Invalid OU Distinguished Name provided [$DistName]`nValidate the OU and try again."
            exit
        }
    }
}
## Add specified computer names
If ($ComputerName) {
    ForEach ($computer in $ComputerName) {
        If ($computer -notin $computers) {
            $computers += $computer
        }
    }
}
## Add computers from a list file
If ($ComputerList) {
    try {
        if (-not (Test-Path -Path $ComputerList -ErrorAction SilentlyContinue)) {
            throw [System.IO.FileNotFoundException]
        }
        ForEach ($computer in (Get-Content -Path $ComputerList -ErrorAction Inquire)) {
            $computers += $computer
        }
    } catch {
        Write-Warning "List file $ComputerList not found, please verify file path and location and try again."
        exit
    }
}

## If we're running only locally we'll want to go ahead and set the $computers variable
If ($Local) { $computers += 'localhost' }

## Calculate the total number of computers
$totalComputers = $computers.Count

## Set the default CSV file name and path
$defaultCSV = "Event-Log-Audit_$(Get-Date -f 'MM-dd-yy').csv"
$defaultRoot = $pwd.Path

## If 'CSV' is set, check the output directory exists, if it does not, or CSV is not set, set $CSV to current working directory
If ($CSV) {
    $validate = $false
    do {
        try {
            ## Verify the provided $CSV path argument is a valid reachable location
            if (-not (Test-Path -Path (Split-Path $CSV -Parent))) {
                throw [System.IO.FileNotFoundException]::new()
            } elseif ($CSV -notlike "*.csv") {
                throw [System.IO.FileFormatException]::new()
            } else {
                $validate = $true
            }
        } catch [System.IO.FileNotFoundException] {
            Write-Warning "Output directory '$CSV' not found, please verify file path and location..."
            Write-Host -ForegroundColor Yellow "Type Ctrl+C to exit or correct the path below."
            $check = Read-Host "Type the corrected path here, or hit 'Enter' to use the default name and path `n[$defaultRoot\$defaultCSV]"

            If ($check) {
                Write-Host -ForegroundColor Green "CSV output path set to [$check]..."
                $CSV = $check
            }
            Else {
                $CSV = "$defaultRoot\$defaultCSV"
                Write-Host -ForegroundColor Green "CSV output path set to [$CSV]..."
            }
        } catch [System.IO.FileFormatException] {
            Write-Warning "Invalid file extension '$CSV', please verify file path and extension is set to '.csv'..."
            Write-Host -ForegroundColor Yellow "Type Ctrl+C to exit or correct the filename below."
            $check = Read-Host "Type the corrected path here, or hit 'Enter' to use the default name `n[$defaultRoot\$defaultCSV]"

            If ($check) {
                Write-Host -ForegroundColor Green "CSV filename set to [$check]..."
                $CSV = $check
            }
            Else {
                $CSV = "$defaultRoot\$defaultCSV"
                Write-Host -ForegroundColor Green "CSV output path set to [$CSV]..."
            }
        }
    } while (-not $validate)
}
Else {
    ## Just in case $pwd is funky
    If ($defaultRoot) { $CSV = "$defaultRoot\$defaultCSV" }
    Else { $CSV = "$PSScriptRoot\$defaultCSV" }
    If (-not $Quiet -and -not $Defaults) {
        Write-Host -ForegroundColor Yellow "No output path specified, using local directory:`n[" -NoNewline
        Write-Host -ForegroundColor Green "$CSV" -NoNewline
        Write-Host -ForegroundColor Yellow "]..."
        Start-Sleep 3
    }
}

## Let's see if there are any saved user settings in the user's profile
$settings_file = "$env:USERPROFILE\AppData\Local\get-eventlogaudit.json"
If ((Test-Path -Path $settings_file) -eq 'TRUE' -and -not $Defaults) {
    $eventCategories = Get-Content -Path $settings_file | ConvertFrom-Json
    $eventCategories = $eventCategories | ConvertPSObjectToHashtable
}
Else {
    $eventCategories = Set-DefaultSelections
}
## Now let's sort the values in the categories hashtable
$eventCategories = $eventCategories.GetEnumerator() | Sort-Object -Property key

## If we're running interactive let's display a menu to select the audit items
## Or make sure the categories are pulled from the default/user profile
$selectedCategories = @()
If (-not $Quiet -and -not $Defaults) { $selectedCategories = Show-Selection -showCategories $eventCategories }
Else { $selectedCategories = $eventCategories }

## Now let's consolidate the selected items from the menu selection or user saved settings
$auditItems = @()
$selectedCategories.GetEnumerator() | % { If ($_.Value.Enabled -eq $true) { $auditItems += $_ } }

## Now that they're consolidated lets prep the WinEvent Queries so we don't duplicate work
$uniqueEvents = @{}

## Iterate through the original array to populate the WinEvent queries
ForEach ($event in $auditItems.GetEnumerator()) {
    $logName = $event.Value.LogName
    $eventIDs = $event.Value.EventIDs -split " "

    If (-not $uniqueEvents.ContainsKey($logName)) {
        $uniqueEvents[$logName] = @()
    }

    ForEach ($eventID in $eventIDs) {
        If ($uniqueEvents[$logName] -notcontains $eventID) {
            $uniqueEvents[$logName] += $eventID
        }
    }
}

## Consolidate to an array
$resultArray = @()

## Convert hashtable to array
ForEach ($logName in $uniqueEvents.Keys) {
    $resultArray += [PSCustomObject]@{
        LogName  = $logName
        EventIDs = ($uniqueEvents[$logName] -join ',')
    }
}

## Output the consolidated array
$auditItems = $resultArray

## If we're running standalone we'll need to get some admin credentials here
If ($Standalone) {
    $credentialList = @()
    $credentialList = Get-StandaloneCredential -machines $computers
}

## Now that we have the items properly sorted into individual query data,
## gathered credentials if necessary, and set the CSV output directory,
## we will start the queries
$computerStep = 0
$computerStart = Get-Date
ForEach ($computer in $computers) {
    $outputCSV = @()

    ## Again if we are standalone we need to pass credentials to the remote query
    ## so we'll extract that info from the previous credential object for this computer
    If ($Standalone) {
        $creds = ($credentialList | where { $_.ComputerName -eq $computer })[0] ## The '[0]' is just to ensure we only get the first instance of credentials for the matching name....in case we messed up elsewhere
        $pscredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $creds.USERNAME, $creds.PASSWORD
    }

    ## Look away if you were an average mathematics student
    ## Increment the computer step counter and update progress if not in quiet mode
    If (-not $Quiet) {
        $computerStep++
        $elapsedComputers = ("{0:hh\:mm\:ss}" -f [timespan]::FromSeconds(((Get-Date) - $computerStart).TotalSeconds)) #                                              ^  ^
        ## Calculate the average time it's taking to complete on each computer, if we're on the first step I asked this cat an estimated time and he said 5 minutes (˃ᆺ˂)
        $averageComputer = If ($computerStep -ne 1) { ((Get-Date) - $computerStart).TotalSeconds/$computerStep } Else { 300 }
        $timeremainingComputer = ([timespan]::FromSeconds($averageComputer * ($totalComputers - $computerStep))).TotalSeconds

        Write-ProgressHelper -id 1 -StepNumber $computerStep -Activity "Gathering Logs from $computer..." -Message "Processing...        Total Elapsed Time: $elapsedComputers" -remaining $timeremainingComputer -totalSteps $totalComputers
        $logStep = 0
        $logStart = Get-Date
        $totalLogs = $auditItems.Count
    }
    ForEach ($item in $auditItems) {
        $output = @()
        ## Increment the log step counter and update progress if not in quiet mode
        If (-not $Quiet) {
            $logStep++
            $elapsedLogs = ("{0:hh\:mm\:ss}" -f [timespan]::FromSeconds(((Get-Date) - $logStart).TotalSeconds))
            ## Calculate the average time it's taking to query each log type, if we're on the first step I arbitrarily picked 2 minutes >'-'<
            $averageLog = If ($logStep -ne 1) { ((Get-Date) - $logStart).TotalSeconds/$logStep } Else { 120 }
            $timeremainingLog = ([timespan]::FromSeconds($averageLog * ($totalLogs - $logStep))).TotalSeconds

            Write-ProgressHelper -parentid 1 -StepNumber $logStep -Activity "Querying $($item.LogName) logs from $computer..." -Message "Gathering $($item.LogName) logs...        Log Elapsed Time: $elapsedLogs" -remaining $timeremainingLog -totalSteps $totalLogs
        }
        ## Splat the parameters so we can dynamically handle credentials
        $logParams = @{
            ComputerName=$computer
            LogName=$item.LogName
            EventIDs=$item.EventIDs
        }
        ## Assign the corresponding credential for this machine if we're doing a standalone remote query
        If ($Standalone) {
            $logParams.Credential=$pscredential
        }

        $outputLogs += Get-EventLogData @logParams
    }
    
    ForEach ($log in $outputLogs) {
        $outputCSV += [pscustomobject]@{ ComputerName=$computer; TimeCreated=$log.TimeCreated; ID=$log.ID; LevelDisplayName=$log.LevelDisplayName; Message=$log.Message }
    }
    If ($outputCSV -and -not $Quiet) { Write-Host -ForegroundColor Green "Logs gathered for $computer, writing logs to CSV..." }
    ElseIf (-not $outputCSV -and -not $Quiet) { 
        Write-Host -ForegroundColor Yellow "No current logs found for $computer....`n"
        Write-Host "Moving to the next machine..."
    }

    ## Let's resolve the computer name for the current iteration and set it more appropriately if we are at 'localhost'
    If ($computer -ne 'localhost') {
        ## Don't want to step n the user's toes with what they want to name the file, so let's extract the filename
        ## then reinject it into the path adding which computer we're auditing currently, this method also doesn't
        ## care if the default name is used
        $filename = $CSV.Replace("$(Split-Path $CSV -Parent)\",'')
        $CSVPath = $CSV.Replace("$filename", "$computer`_$filename")
    }
    Else {
        $filename = $CSV.Replace("$(Split-Path $CSV -Parent)\",'')
        $CSVPath = $CSV.Replace("$filename", "$env:COMPUTERNAME`_$filename")
    }

    $outputCSV | Export-CSV -Path $CSVPath -NoTypeInformation -Append
}

Write-Host -ForegroundColor Green "`nComplete!`n"
Write-Host "You can find your Audit files here: [" -NoNewline
Write-Host -ForeGroundColor Yellow "$(Split-Path $CSV -Parent)" -NoNewline
Write-Host "]`n"
$openfolder = Read-Host "Would you like to open the folder in explorer? Y/N"
If ($openfolder.tolower -eq 'y') { Invoke-Item -Path $(Split-Path $CSV -Parent) }