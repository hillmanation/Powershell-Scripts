## Managed security groups periodic audit script
## Created by Jake Hillman CBTS SDS Team
Import-Module ActiveDirectory

## Get a list of all of the controlled groups
$groups = (Get-ADGroup -filter * -SearchBase "OU=Managed Security Groups,DC=COM" -SearchScope Subtree).Name
$groups += (Get-ADGroup -filter * | where { $_.Name -like "*Admin*" -and $_.DistinguishedName -notlike "*Managed Security Groups*" -and $_.Name -notlike "Hyper-V*" -and $_.Name -notlike "*Storage*" -and $_.Name -notlike "*key*" -and $_.Name -notlike "" }).Name
$groups = $groups | Sort-Object

## Set the output folder name and create other information
$year = Get-Date -Format "yyyy"
$weekofyear = Get-Date -UFormat %V
---> $logfolder = "\\Share\Folder_1\Folder_2\Managed Security Groups Audit\"
$logname = "Managed_Groups_Audit_Week_" + $weekofyear + ".csv"
$lastlog = "Managed_Groups_Audit_Week_" + ($weekofyear - 1) + ".csv"
$yearFolder = $logfolder + $year + "\"

## Create the year folder if it does not exist
If (!(Test-Path -Path $yearfolder)) { New-Item -Path $logfolder -Name $year -ItemType Directory -Force | Out-Null }

$filename = $yearfolder + $logname
$previousauditfile = $yearfolder + $lastlog
$lastaudit = Import-CSV $previousauditfile

$output = @()

## Get the group members data for each group to be sorted into a CSV file
ForEach ($group in $groups) {

    $accounts,$MembersAdded,$MembersRemoved = ""

    $members = (Get-ADGroupMember -Identity $group).samaccountname | Sort-Object -Property samaccountname

    ## Format the output with commas
    ForEach ($member in $members) { $accounts += $member + ", " }

    ## Trim the last comma and space off of the variable
    If ($accounts -ne $NULL) { $accounts = $accounts.TrimEnd(', ') }

    ## Check each account from the current week against the last audit CSV
    ## to see if any have been added or removed
    ForEach ($lastaccount in $lastaudit) { 
        If ($group -like $lastaccount.Group) { ## Only check for which accounts were added/removed if the group members for this week do not match the list from last week
            $lastmembers = (($lastaccount.GroupMembers).Replace(",","")).split(" ")
            $currentmembers = ($accounts.Replace(",","")).split(" ")

            If ($lastmembers -ne $currentmembers) {
                ForEach ($lastmember in $lastmembers) { If ($lastmember -notin $currentmembers) { $MembersRemoved += $lastmember + ", " } }
                ForEach ($currentmember in $currentmembers) { If ($currentmember -notin $lastmembers) { $MembersAdded += $currentmember + ", " } }
                If ($MembersRemoved -ne $NULL) { $MembersRemoved = $MembersRemoved.TrimEnd(', ') }
                If ($MembersAdded -ne $NULL) { $MembersAdded = $MembersAdded.TrimEnd(', ') }
            }
        }
    }
    ## Format the output into a custom object and append it to the CSV for this week
    $output = [pscustomobject]@{ Group = $group; GroupMembers = $accounts; GroupMembersAdded = $MembersAdded; GroupMembersRemoved = $MembersRemoved  }
    $output | Export-CSV -Path $filename -NoTypeInformation -Append
}