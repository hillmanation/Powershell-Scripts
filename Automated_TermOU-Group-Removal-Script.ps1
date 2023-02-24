## Check the Termination OU for accounts that still have AD Groups and remove them

Import-Module ActiveDirectory

$descrDate = Get-Date -Format "MM/dd/yyyy"
$termusers = Get-ADUser -Filter * -SearchBase "OU=Termination,DC=COM" -SearchScope Subtree -properties Name,SamAccountName,Enabled,MemberOf | where { $_.MemberOf -ne $NULL }

If ($termusers -ne $NULL) {

## Check for year and month folder in Log folder and create folders if needed
$filedate = Get-Date -Format "_MM_dd_yyyy"
$blank,$month,$day,$year = $filedate.split("_")
$fullmonth = get-date -UFormat %B
---> $rootfolder = "\\Share\Folder_1\Folder_2\\AD Account Termination Logs\"
$yearFolder = $rootfolder + $year + "\"

If (!(Test-Path -Path $yearfolder)) { New-Item -Path $rootfolder -Name $year -ItemType Directory -Force | Out-Null }

$monthfolder = $month + " - " + $fullmonth
$logfolder = $yearfolder + "\" + $monthfolder + "\"

If (!(Test-Path -Path $logfolder)) { New-Item -Path $yearfolder -Name $monthfolder -ItemType Directory -Force | Out-Null }

$fileNameCSV = $logFolder + "AD_User_Termination_Audit_" + $fullmonth + ".csv"
$fileNameLog = $logFolder + "AD_User_Termination_Log_" + $filedate + ".txt"
    
$date = Get-Date

## Start text log
"-----------------$date----------------`r`n---------Starting AD User Group Removal Script--------`r`n----------------------------------------------------`r`n`r`n" | Out-File $filenameLog -Append

ForEach ($user in $termusers) {
    $samaccountname = $user.samAccountName
    $groups = $user.MemberOf
    $name = $user.Name
    $OU = $user.DistinguishedName -replace '^.+?(?<!\\),',''

    "Account $samaccountname for user $name found in Termination OU with Group Membership, starting Group Removal tasks...`r`n`r`nRemoving User from all AD Groups..." | Out-File $filenameLog -Append
        
    ForEach ($group in $groups) { Remove-ADGroupMember -Identity $group -Members $samaccountname -Confirm:$false; $grouplist += $group + ";" }

    "Logging user information into Audit CSV..." | Out-File $filenameLog -Append

    ## Format the user's information into a list that can be exported to CSV
    $output = [pscustomobject]@{ samAccountName = $samaccountname; Name = $name; DateTerminated = $descrdate; OrganizationalUnit = $OU; GroupsRemoved = $grouplist }
    $output | Export-CSV -Path $filenameCSV -NoTypeInformation -Append
    $grouplist = $NULL
    
    "User $name all Groups removed and audit logs created.`r`n`r`n" | Out-File $filenameLog -Append  
    }
}

$end = Get-Date
$elapsed = (($end - $date).totalSeconds)
"------AD User Group Removal Script Completed------`r`n------------------$end------------------`r`n-----------Elapsed time: $elapsed seconds------------`r`n`r`n" | Out-File $filenameLog -Append

## Cleanup
$grouplist,$output,$lastlogon,$samaccountname,$name,$OU,$user,$termusers,$usertype = $NULL