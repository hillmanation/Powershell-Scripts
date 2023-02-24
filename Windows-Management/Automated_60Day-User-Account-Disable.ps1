Import-Module ActiveDirectory
Set-ExecutionPolicy -ExecutionPolicy Bypass -Force -Confirm:$false

$date = Get-Date
$descrDate = Get-Date -Format "MM/dd/yyyy"
$users = Get-ADuser -filter * -Properties Name,samAccountName,DistinguishedName,LastLogonDate,Created | where { $_.Enabled -eq $True -and $_.samAccountName -notlike "svc_*" -and $_.samAccountName -notlike "root" -and $_.samAccountName -notlike "*service*" -and $_.LastLogonDate -ne $NULL -and (New-TimeSpan -start $_.LastLogonDate -end $date).Days -gt 60 -and (New-TimeSpan -start $_.Created -end $date).Days -gt 60 } | Select-Object Name,samAccountName,DistinguishedName,LastLogonDate,Created

## Check for year and month folder in Log folder and create folders if needed
$filedate = Get-Date -Format "_MM_dd_yyyy"
$blank,$month,$day,$year = $filedate.split("_")
$fullmonth = get-date -UFormat %B
---> $rootfolder = "\\Share\Folder_1\Folder_2\\AD Account Disable Logs\"
$yearFolder = $rootfolder + $year + "\"

If (!(Test-Path -Path $yearfolder)) { New-Item -Path $rootfolder -Name $year -ItemType Directory -Force | Out-Null }

$monthfolder = $month + " - " + $fullmonth
$outfolder = $yearfolder + "\" + $monthfolder + "\"

If (!(Test-Path -Path $outfolder)) { New-Item -Path $yearfolder -Name $monthfolder -ItemType Directory -Force | Out-Null }

$userfolder = $outfolder + "\" + "Users\"

If (!(Test-Path -Path $userfolder)) { New-Item -Path $outfolder -Name "Users" -ItemType Directory -Force | Out-Null }

$fileNameCSV = $userFolder + "AD_User_Disabled_Audit_" + $fullmonth + ".csv"
$fileNameLog = $userFolder + "AD_User_Disabled_Log_" + $filedate + ".txt"

## Start text log
"--------------------$date--------------------`r`n----------Starting AD User Inactivity Audit Script---------`r`n-----------------------------------------------------------`r`n`r`n" | Out-File $filenameLog -Append

If ($users -ne $NULL) {
    ForEach ($user in $users) { 
    
        $samaccountname = $user.samAccountName
        $lastlogon = $user.LastLogonDate
        $created = $user.Created
        $name = $user.Name
        $OU = $user.DistinguishedName -replace '^.+?(?<!\\),',''

        "Account $samaccountname for user $name last logged in $lastlogon, created on $created...`r`n`r`nDisabling user account..." | Out-File $filenameLog -Append

        ## Disable the account in AD
        Disable-ADAccount -identity $samaccountname

        If ((Get-AdUser -identity $samaccountname -Properties Enabled | Select-Object Enabled).Enabled -ne $False) { 
            "---USER ACCOUNT WAS NOT DISABLED, this could be due to a permissions error, please investigate---`r`n`r`n" | Out-File $filenameLog -Append
            Continue
        }

        "Account disabled, generating new description and noting new disabled on date..." | Out-File $filenameLog -Append

        $newdescr = "Disabled over 60 days inactivity via automated script $descrdate"

        ## Uncomment the below section and remove the above line to change the description update to keep the existing information in the description
        <# ## Get the current Description create a new one adding the new disabled on date
        $descr = (Get-ADUser -identity $samaccountname -Properties Description | Select-Object Description).Description
        $newdescr = "Disabled over 60 days inactivity via automated script $descrdate - " + $descr

        ## The description field in AD is limited to 1024 characters, so for safety, check the string to ensure it won't go over
        If (($newdescr | Measure-Object -Character).Characters -ge 1023) { $newdescr = $newdescr.Substring(0,1023) } #>

        ## Set the Description to the new one
        Set-ADUser -Identity $samaccountname -Description $newdescr

        ## Get the groups the user is currently a member of 
        $groups = (get-aduser -identity $samaccountname -properties Memberof | Select-Object Memberof).MemberOf

        "Notating all AD groups and logging user information into Audit CSV..." | Out-File $filenameLog -Append

        ## Format the user's information into a list that can be exported to CSV
        $groups | % { $grouplist += $_ + ";" }
        $output = [pscustomobject]@{ samAccountName = $samaccountname; Name = $user.Name; DateDisabled = $descrdate; Reason = '60 Day Inactivity'; OrganizationalUnit = $OU; GroupsRemoved = 'False'; Memberof = $grouplist }
        $output | Export-CSV -Path $filenameCSV -NoTypeInformation -Append

        "User $name has been successfully disabled and audit logs created.`r`nMoving to next user...`r`n`r`n" | Out-File $filenameLog -Append

        ## Cleanup
        $grouplist,$output,$lastlogon,$samaccountname,$name,$OU,$user = $NULL
       
    }
}
Else { "-----------------No inactive account found-----------------`r`n`r`n" | Out-File $filenameLog -Append }

$end = Get-Date
$elapsed = (($end - $date).totalSeconds)
"---------AD User Inactivity Audit Script Completed---------`r`n--------------------$end--------------------`r`n--------------Elapsed time: $elapsed seconds--------------`r`n`r`n" | Out-File $filenameLog -Append