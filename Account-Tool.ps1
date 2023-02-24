#############################
## Created By Jake Hillman ##
#############################

Import-Module ActiveDirectory
##Set-ExecutionPolicy -ExecutionPolicy Bypass -Force
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$privuser = [Environment]::UserName
$descrDate = Get-Date -Format "MM/dd/yyyy"

Function Find-ADUser ($FindADUsername) {
    $usercheck = (Get-ADUser -filter * -properties SamAccountName | Select-Object Samaccountname).SamaccountName

    If ($FindADUsername -ne "" -and $FindADUsername -ne $NULL -and $FindADUsername -in $usercheck) {
        
        $resetbutton.enabled = $TRUE

        $user = Get-ADuser -Identity $FindADUsername -properties Name,Samaccountname,Enabled,LockedOut,MemberOf,LastBadPasswordAttempt,LastLogonDate,PasswordExpired,PasswordLastSet,DistinguishedName
        $userlabel.Text = 'Name of user: ' + $user.Name
        If ($user.LockedOut -eq $TRUE) { $UnlockButton.Enabled = $TRUE }
        Else { $UnlockButton.Enabled = $FALSE }
        $lockedlabel.Text = "Account currently locked out: " + $user.LockedOut
        If ($user.Enabled -eq $FALSE) { $enablebutton.Enabled = $TRUE }
        Else { $enableButton.Enabled = $FALSE }
        $enabledlabel.Text = 'Account Enabled: ' + $user.Enabled
        $expiredlabel.Text = 'Password expired: ' + $user.PasswordExpired
        $passlastlabel.Text = 'Password last set: ' + $user.PasswordLastSet
        $lastbadlabel.Text = 'Last Bad pwd attempt: ' + $user.LastBadPasswordAttempt
        $logonlabel.Text = 'Last Successful logon: ' + $user.LastLogonDate
        If ($user.Memberof -like "*VDI*") { ForEach ($group in ($user.Memberof -like "*VDI*")) { $groupdisplay += ($group -replace  "(CN=)(.*?),.*",'$2') + " "}; $grouplabel.Text = 'User in VDI Group: ' + $groupdisplay; $groupdisplay = $NULL }
        Else { $grouplabel.Text = 'User in VDI Group: False' }
        $oulabel.Text = 'User OU: ' + ($user.DistinguishedName -Replace 'CN=[^=]*,|,DC=.+$')
    }
    Else { $resetbutton.Enabled = $False; $outputlabel.BackColor="Red";$outputlabel.ForeColor="Yellow";$outputlabel.Text = "ERROR!: No user account found for $FindADUsername!" }
}

Function Unlock-ADUser ($userUnlock) { Unlock-ADAccount -Identity $userUnlock; $lockedcheck = (Get-ADUser -identity $userUnlock -properties LockedOut).LockedOut
    If ($lockedcheck -eq $FALSE) { Find-ADUser $userUnlock; $outputlabel.BackColor="Green";$outputlabel.ForeColor="Yellow";$outputlabel.Text = 'User Account Unlocked Successfully!' }
    Else { $outputlabel.BackColor="Red";$outputlabel.ForeColor="Yellow";$outputlabel.Text = 'ERROR!: Unable to Unlock Account!' }
}

Function Enable-ADUser ($userEnable) { Enable-ADAccount -Identity $userEnable; $enabledcheck = (Get-ADUser -identity $userEnable -properties Enabled).Enabled
    If ($enabledcheck -eq $TRUE) { Find-ADUser $userEnable; $outputlabel.BackColor="Green";$outputlabel.ForeColor="Yellow";$outputlabel.Text = 'User Account Enabled Successfully!'
        ## Get the current Description create a new one adding the new enabled on date
        $descr = (Get-ADUser -identity $userenable -Properties Description | Select-Object Description).Description
        $newdescr = "Enabled by $privuser on $descrdate - " + $descr

        ## The description field in AD is limited to 1024 characters, so for safety, check the string to ensure it won't go over
        If (($newdescr | Measure-Object -Character).Characters -ge 1023) { $newdescr = $newdescr.Substring(0,1023) }

        ## Set the Description to the new one
        Set-ADUser -Identity $userenable -Description $newdescr
    }
    Else { $outputlabel.BackColor="Red";$outputlabel.ForeColor="Yellow";$outputlabel.Text = 'ERROR!: Unable to Enable Account!' }
}

Function Reset-ADUser {

    param ( [string]$resetuser, [string]$newpassword, [string]$confirmpass )

    If ($newpassword -eq "" -or $confirmpass -eq "") { $verifylabel.Text = 'Please Enter a Password!'; $verifylabel.BackColor='Red';$verifylabel.ForeColor="Yellow" }
    elseif ($newpassword -ne $confirmpass) { $newpassword,$confirmpass = $NULL; $verifylabel.Text = 'Passwords do not match!'; $verifylabel.BackColor='Red';$verifylabel.ForeColor="Yellow" } ## Validate the user input and delete the unencrypted instances of the password
    else { $NewCreds = $newpassword | ConvertTo-SecureString -AsPlainText -Force; $passtest1,$passtest2,$newpassword,$confirmpass = $NULL 
        Try { Set-ADAccountPassword -Identity $resetuser -NewPassword $NewCreds -reset -ErrorAction SilentlyContinue
              $verifylabel.Text = 'Password changed Successfully!'
              $verifylabel.BackColor='Green';$verifylabel.ForeColor="Yellow"
              Find-ADuser $resetuser
        }
        Catch [Microsoft.ActiveDirectory.Management.ADPasswordComplexityException] { $verifylabel.Text = 'Does not meet complexity!'; $verifylabel.BackColor='Red';$verifylabel.ForeColor="Yellow" }
        Catch [System.UnauthorizedAccessException] { $verifylabel.Text = 'Invalid Permissions!'; $verifylabel.BackColor='Red';$verifylabel.ForeColor="Yellow" }
    }

}

Function Pass-Intake ($passreset) {

    $passform = New-Object System.Windows.Forms.Form
    $passform.Text = "Reset password for $passreset"
    $passform.Size = New-Object System.Drawing.Size(350,130)
    $passform.StartPosition = 'CenterScreen'

    $passlabel = New-Object System.Windows.Forms.Label
    $passlabel.Location = New-Object System.Drawing.Point(10,5)
    $passlabel.Size = New-Object System.Drawing.Size(280,15)
    $passlabel.Text = 'Enter a New Password:'
    $passform.Controls.Add($passlabel)

    $newpass = New-Object System.Windows.Forms.MaskedTextBox
    $newpass.Location = New-Object System.Drawing.Point(10,20)
    $newpass.size = New-Object System.Drawing.Size(180,20)
    $newpass.PasswordChar = "*"
    $newpass.focus()
    $passform.Controls.Add($newpass)

    $confirmlabel = New-Object System.Windows.Forms.Label
    $confirmlabel.Location = New-Object System.Drawing.Point(10,45)
    $confirmlabel.Size = New-Object System.Drawing.Size(280,15)
    $confirmlabel.Text = 'Confirm the New Password:'
    $passform.Controls.Add($confirmlabel)

    $confirmpass = New-Object System.Windows.Forms.MaskedTextBox
    $confirmpass.Location = New-Object System.Drawing.Point(10,60)
    $confirmpass.size = New-Object System.Drawing.Size(180,20)
    $confirmpass.PasswordChar = "*"
    $confirmpass.Add_KeyDown({If ($_.KeyCode -eq "Enter")
            {  Reset-ADUser -resetuser $passreset -newpassword $newpass.Text -confirmpass $confirmpass.Text }})
    $passform.Controls.Add($confirmpass)

    $verifylabel = New-Object System.Windows.Forms.Label
    $verifylabel.Location = New-Object System.Drawing.Point(210,20)
    $verifylabel.Size = New-Object System.Drawing.Size(105,25)
    $passform.Controls.Add($verifylabel)

    $passbutton =  New-Object System.Windows.Forms.Button
    $passbutton.Location = New-Object System.Drawing.Point(240,60)
    $passbutton.Size = New-Object System.Drawing.Size(75,20)
    $passbutton.Text = 'Change PW'
    $passbutton.Add_Click({ Reset-ADUser -resetuser $passreset -newpassword $newpass.Text -confirmpass $confirmpass.Text })
    $passform.Controls.Add($passbutton)

    $passform.Topmost = $TRUE
    $result2 = $passform.ShowDialog()
}
    ## Start building the form for the user input for the script

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Compass Account Tool'
    $form.Size = New-Object System.Drawing.Size(320,420)
    $form.StartPosition = 'CenterScreen'

    $cancelbutton = New-Object System.Windows.Forms.Button
    $cancelbutton.Location = New-Object System.Drawing.Point(120,345)
    $cancelbutton.Size = New-Object System.Drawing.Size(70,23)
    $cancelbutton.Text = 'Exit'
    $cancelbutton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $cancelbutton
    $form.Controls.Add($cancelbutton)

    $userlabel = New-Object System.Windows.Forms.Label
    $userlabel.Location = New-Object System.Drawing.Point(10,20)
    $userlabel.Size = New-Object System.Drawing.Size(280,20)
    $userlabel.Text = 'Enter the Username of the account to lookup:'
    $form.Controls.Add($userlabel)

    $usertextbox = New-Object System.Windows.Forms.TextBox
    $usertextbox.Location = New-Object System.Drawing.Point(10,40)
    $usertextbox.size = New-Object System.Drawing.Size(225,20)
    $usertextbox.Add_KeyDown({If ($_.KeyCode -eq "Enter")
            { Find-ADUser $usertextbox.Text; }})
    $form.Controls.Add($usertextbox)

    $findbutton =  New-Object System.Windows.Forms.Button
    $findbutton.Location = New-Object System.Drawing.Point(240,40)
    $findbutton.Size = New-Object System.Drawing.Size(50,20)
    $findbutton.Text = 'Find'
    $findbutton.Add_Click({Find-ADUser $usertextbox.Text})
    $form.Controls.Add($findbutton)

    $userlabel = New-Object System.Windows.Forms.Label
    $userlabel.Location = New-Object System.Drawing.Point(10,70)
    $userlabel.Size = New-Object System.Drawing.Size(280,20)
    $userlabel.Text = 'Name of user:'
    $form.Controls.Add($userlabel)

    $lockedlabel = New-Object System.Windows.Forms.Label
    $lockedlabel.Location = New-Object System.Drawing.Point(10,90)
    $lockedlabel.Size = New-Object System.Drawing.Size(280,20)
    $lockedlabel.Text = "Account currently locked out: "
    $form.Controls.Add($lockedlabel)

    $enabledlabel = New-Object System.Windows.Forms.Label
    $enabledlabel.Location = New-Object System.Drawing.Point(10,110)
    $enabledlabel.Size = New-Object System.Drawing.Size(226,20)
    $enabledlabel.Text = 'Account Enabled: '
    $form.Controls.Add($enabledlabel)

    $expiredlabel = New-Object System.Windows.Forms.Label
    $expiredlabel.Location = New-Object System.Drawing.Point(10,130)
    $expiredlabel.Size = New-Object System.Drawing.Size(226,20)
    $expiredlabel.Text = 'Password expired: '
    $form.Controls.Add($expiredlabel)

    $passlastlabel = New-Object System.Windows.Forms.Label
    $passlastlabel.Location = New-Object System.Drawing.Point(10,150)
    $passlastlabel.Size = New-Object System.Drawing.Size(226,20)
    $passlastlabel.Text = 'Password last set: '
    $form.Controls.Add($passlastlabel)

    $lastbadlabel = New-Object System.Windows.Forms.Label
    $lastbadlabel.Location = New-Object System.Drawing.Point(10,170)
    $lastbadlabel.Size = New-Object System.Drawing.Size(226,20)
    $lastbadlabel.Text = 'Last Bad pwd attempt: '
    $form.Controls.Add($lastbadlabel)

    $logonlabel = New-Object System.Windows.Forms.Label
    $logonlabel.Location = New-Object System.Drawing.Point(10,190)
    $logonlabel.Size = New-Object System.Drawing.Size(226,20)
    $logonlabel.Text = 'Last Successful logon: '
    $form.Controls.Add($logonlabel)

    $grouplabel = New-Object System.Windows.Forms.Label
    $grouplabel.Location = New-Object System.Drawing.Point(10,210)
    $grouplabel.Size = New-Object System.Drawing.Size(300,20)
    $grouplabel.Text = 'User in VDI Group: '
    $form.Controls.Add($grouplabel)

    $oulabel = New-Object System.Windows.Forms.Label
    $oulabel.Location = New-Object System.Drawing.Point(10,230)
    $oulabel.Size = New-Object System.Drawing.Size(300,40)
    $oulabel.Text = 'User OU: '
    $form.Controls.Add($oulabel)

    $UnlockButton =  New-Object System.Windows.Forms.Button
    $UnlockButton.Location = New-Object System.Drawing.Point(10,270)
    $UnlockButton.Size = New-Object System.Drawing.Size(70,20)
    $UnlockButton.Text = 'Unlock'
    $UnlockButton.Enabled = $False
    $UnlockButton.Add_Click({Unlock-ADUser $usertextbox.Text})
    $form.Controls.Add($UnlockButton)

    $enablebutton =  New-Object System.Windows.Forms.Button
    $enablebutton.Location = New-Object System.Drawing.Point(120,270)
    $enablebutton.Size = New-Object System.Drawing.Size(70,20)
    $enablebutton.Text = 'Enable'
    $enablebutton.Enabled = $False
    $enablebutton.Add_Click({Enable-ADUser $usertextbox.Text})
    $form.Controls.Add($enablebutton)

    $resetbutton =  New-Object System.Windows.Forms.Button
    $resetbutton.Location = New-Object System.Drawing.Point(225,270)
    $resetbutton.Size = New-Object System.Drawing.Size(70,20)
    $resetbutton.Text = 'Reset PW'
    $resetbutton.Enabled = $False
    $resetbutton.Add_Click({Pass-Intake $usertextbox.Text})
    $form.Controls.Add($resetbutton)

    $outputlabel = New-Object System.Windows.Forms.Label
    $outputlabel.Location = New-Object System.Drawing.Point(10,300)
    $outputlabel.Size = New-Object System.Drawing.Size(280,15)
    $form.Controls.Add($outputlabel)

    $adminlabel = New-Object System.Windows.Forms.Label
    $adminlabel.Location = New-Object System.Drawing.Point(10,320)
    $adminlabel.Size = New-Object System.Drawing.Size(280,20)
    $adminlabel.Text = "Privleged User modifying account: $privuser"
    $form.Controls.Add($adminlabel)

    $form.Topmost = $TRUE

    $form.Add_Shown({$usertextbox.Select()})
    $result = $form.ShowDialog()

    <### Check for year and month folder in Log folder and create folders if needed
    $filedate = Get-Date -Format "_MM_dd_yyyy"
    $blank,$month,$day,$year = $filedate.split("_")
    $fullmonth = get-date -UFormat %B
    $rootfolder = "\\aetpdata\Ourstuff\_SDS Ops Folder\AD Account Disable Logs\"
    $yearFolder = $rootfolder + $year + "\"

    If (!(Test-Path -Path $yearfolder)) { New-Item -Path $rootfolder -Name $year -ItemType Directory -Force | Out-Null }

    $monthfolder = $month + " - " + $fullmonth
    $outfolder = $yearfolder + "\" + $monthfolder + "\"

    If (!(Test-Path -Path $outfolder)) { New-Item -Path $yearfolder -Name $monthfolder -ItemType Directory -Force | Out-Null }

    If ($username -contains "zz") { $usertype = "Admin"; $usertypes = "Admins" }
    Else { $usertype = "User"; $usertypes = "Users" }

    $logfolder = $outfolder + "\" + $usertypes + "\"

    If (!(Test-Path -Path $logfolder)) { New-Item -Path $outfolder -Name $usertypes -ItemType Directory -Force | Out-Null }

    $fileNameCSV = $logFolder + "AD_" + $usertype + "_Disabled_Audit_" + $fullmonth + ".csv"
    $fileNameLog = $logFolder + "AD_" + $usertype + "_Disabled_Log_" + $filedate + ".txt"
    
    $date = Get-Date

    $end = Get-Date
    $elapsed = (($end - $date).totalSeconds)
   #>