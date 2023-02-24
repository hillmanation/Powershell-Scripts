Import-Module ActiveDirectory

$descrDate = Get-Date -Format "MM/dd/yyyy"
$termusers = Get-ADUser -Filter * -SearchBase "OU=Termination,DC=COM" -SearchScope Subtree -properties Name,SamAccountName,Enabled,MemberOf | where { $_.Enabled -eq $TRUE }

If ($termusers -ne $NULL) {

## Check for year and month folder in Log folder and create folders if needed
$filedate = Get-Date -Format "_MM_dd_yyyy"
$blank,$month,$day,$year = $filedate.split("_")
$fullmonth = get-date -UFormat %B
---> $rootfolder = "\\Share\Folder_1\Folder_2\AD Account Termination Logs\"
$yearFolder = $rootfolder + $year + "\"

If (!(Test-Path -Path $yearfolder)) { New-Item -Path $rootfolder -Name $year -ItemType Directory -Force | Out-Null }

$monthfolder = $month + " - " + $fullmonth
$logfolder = $yearfolder + "\" + $monthfolder + "\"

If (!(Test-Path -Path $logfolder)) { New-Item -Path $yearfolder -Name $monthfolder -ItemType Directory -Force | Out-Null }

$fileNameCSV = $logFolder + "AD_User_Termination_Audit_" + $fullmonth + ".csv"
$fileNameLog = $logFolder + "AD_User_Termination_Log_" + $filedate + ".txt"
    
$date = Get-Date

## Start text log
"-----------------$date----------------`r`n---------Starting AD User Termination Script--------`r`n----------------------------------------------------`r`n`r`n" | Out-File $filenameLog -Append

ForEach ($user in $termusers) {
    $samaccountname = $user.samAccountName
    $groups = $user.MemberOf
    $name = $user.Name
    $OU = $user.DistinguishedName -replace '^.+?(?<!\\),',''

    "Account $samaccountname for user $name found in Termination OU, starting Termination tasks...`r`n`r`nDisabling user account..." | Out-File $filenameLog -Append

    ## Disable the account in AD
    Disable-ADAccount -identity $samaccountname -Confirm:$false

    "Account disabled, generating new description and noting new disabled on date..." | Out-File $filenameLog -Append

    $newdescr = "Terminated by Automated Script on $descrdate"

    ## Uncomment the below section and remove the above line to change the description update to keep the existing information in the description
    <# ## Get the current Description create a new one adding the new Terminated on date
    $descr = (Get-ADUser -identity $samaccountname -Properties Description | Select-Object Description).Description
    $newdescr = "Terminated by Automated Script on $descrdate - " + $descr

    ## The description field in AD is limited to 1024 characters, so for safety, check the string to ensure it won't go over
    If (($newdescr | Measure-Object -Character).Characters -ge 1023) { $newdescr = $newdescr.Substring(0,1023) } #>

    ## Set the disabled account description to the new one, noting date disabled
    Set-ADUser -Identity $samaccountname -Description $newdescr

    "Removing user from all AD groups..." | Out-File $filenameLog -Append
        
    ForEach ($group in $groups) { Remove-ADGroupMember -Identity $group -Members $samaccountname -Confirm:$false; $grouplist += $group + ";" }

    "Logging user information into Audit CSV..." | Out-File $filenameLog -Append

    ## Format the user's information into a list that can be exported to CSV
    $output = [pscustomobject]@{ samAccountName = $samaccountname; Name = $name; DateTerminated = $descrdate; OrganizationalUnit = $OU; GroupsRemoved = $grouplist }
    $output | Export-CSV -Path $filenameCSV -NoTypeInformation -Append
    $grouplist = $NULL
    
    "User $name has been successfully terminated and audit logs created.`r`n`r`n" | Out-File $filenameLog -Append  
    }
}

$end = Get-Date
$elapsed = (($end - $date).totalSeconds)
"------AD User Termination Script Completed------`r`n------------------$end------------------`r`n-----------Elapsed time: $elapsed seconds------------`r`n`r`n" | Out-File $filenameLog -Append

## Cleanup
$grouplist,$output,$lastlogon,$samaccountname,$name,$OU,$user,$termusers,$usertype = $NULL