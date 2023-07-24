# Desktop Shortcut Push
# Author: Jacob Hillman <jacob.hillman.it@gmail.com>
# Created: 2023-07-24
<#
.SYNOPSIS
Generates and pushes a shortcut link to the public desktop of machines on the domain.

.DESCRIPTION
If the link exists it will remove the existing link before creating a new one, this
ensures any updates to the link can be pushed out as well with the same script.
 
For now the only parameters are the path to the file, the shortcut name, and option
to pass it a list of computers.
In the future I'll include the ability to push out a list of links.

.PARAMETER OriginalFile
Path to the file you are creating the link/shortcut for. If this is on a share directory, you may have to
specify the UNC path without the drive letter to get this to work.

.PARAMETER LinkName
The name you would like to give the link as it will appear on user's desktops.

.PARAMETER ComputerList
Path to a text file containing a list of computers you wish to push the link to. Do not include a header in this list.

.EXAMPLE
# Standard push of specified link to all non-Server Windows machines found in AD
PS> & '.\Desktop-Shortcut-Push.ps1' -OriginalFile O:\Hillman\npp.exe -LinkName NotePad++

.EXAMPLE
# Run script against list of computers

Create list of computers in a text file as such:
Computer-1
Computer-2
Computer-3

In this example we save it to C:\Temp\Computers.txt

PS> & '.\Desktop-Shortcut-Push.ps1' -OriginalFile O:\Hillman\npp.exe -LinkName NotePad++ -ComputerList C:\Temp\Computers.txt

.LINK
https://github.com/hillmanation/Powershell-Scripts/blob/main/Windows-Management/Desktop-Shortcut-Push.ps1

#>

#Requires -Modules ActiveDirectory
#Requires -RunAsAdministrator
Import-Module ActiveDirectory

param(
        [Parameter(Mandatory=$true,Position=0)][string]$originalfile,
        [Parameter(Mandatory=$true)][string]$linkname,
        [Parameter(Mandatory=$false)][string]$ComputerList
)

# Enable strict mode to protect us against the evils of oopsied unset variables.
Set-StrictMode -Version 3.0

## Check if a computer list is specified, if not pull a list of Workstations from AD
If ($ComputerList -ne "") { $computers = Get-Content $ComputerList }
Else { $computers = (Get-ADComputer -filter * -Properties Name,OperatingSystem | where { $_.OperatingSystem -like "*Windows*" -and $_.OperatingSystem -notlike "*Server*" }).Name }
$linkname = "$linkname.lnk"
$shortcutlocation = "$env:Public\Desktop"

ForEach ($computer in $computers) { 
    
    If (Test-Path -Path "\\$computer\c$\$shortcutlocation\$linkname".Replace("C:\", "")) {
        Remove-Item -Path "\\$computer\c$\$shortcutlocation\$linkname".Replace("C:\", "") -Force -Confirm:$false
    }

    Invoke-Command -ComputerName $computer -AsJob -ScriptBlock {
        ## Build the shortcut object
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut("$using:shortcutlocation\$using:linkname")
        $shortcut.TargetPath = $using:originalfile
        $shortcut.Save()
    } | Out-Null
}