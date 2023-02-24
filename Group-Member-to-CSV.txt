#############################
## Created By Jake Hillman ##
#############################

Import-Module ActiveDirectory
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

## Get a list of all AD Groups, without the builtin groups that would be un-needed
$builtingroups = (Get-ADGroup -filter * -SearchBase "CN=Builtin,DC=EVAV,DC=AE,DC=GE,DC=COM" | Select-Object samaccountname).samaccountname
$defaultgroups = (Get-ADGroup -filter * -SearchBase "CN=Users,DC=EVAV,DC=AE,DC=GE,DC=COM" | where { $_.samaccountname -notlike "*Admin*" -and $_.samaccountname -notlike "Domain Users" } | Select-Object samaccountname).samaccountname
$grouplist = @()
$filedate = Get-Date -Format "_MM_dd_yyyy"

Get-ADGroup -filter * | Select-Object samaccountname | Sort-Object -Property samaccountname | % { If ($_.samaccountname -notin $builtingroups -and $_.samaccountname -notin $defaultgroups) { $grouplist += $_.samaccountname } }

Function GroupMember-to-CSV {
    param ( [array]$groupsforoutput, [string]$urlpath )

    $pathcheck = Check-Path $urlpath

    If ($pathcheck -eq $FALSE) { return }

    Start-Sleep -Seconds 1
    $errorlabel.BackColor="Yellow";$errorlabel.ForeColor="Green";$errorlabel.Text = 'Generating CSV files...'

    ForEach ($groupforoutput in $groupsforoutput) {
        $filename = $urlpath + '\' + $groupforoutput + $filedate + ".csv"

        Get-ADGroupMember -identity $groupforoutput | Select-Object Name,Samaccountname | Export-CSV $filename -NoTypeInformation
        [void] $outputlistbox.Items.add($filename)
    }

    $errorlabel.BackColor="Green";$errorlabel.ForeColor="Yellow";$errorlabel.Text = 'CSV files exported!'
}

Function Check-Path ($pathtocheck) { If ($pathtocheck -eq "") { $errorlabel.BackColor="Red";$errorlabel.ForeColor="Yellow";$errorlabel.Text = 'ERROR!: Please enter a Path!'; return $FALSE }
                                     ElseIf ((Test-Path -path $pathtocheck -ErrorAction SilentlyContinue) -eq $True) { $errorlabel.BackColor="Green";$errorlabel.ForeColor="Yellow";$errorlabel.Text = 'Path exists!'; return $TRUE }
                                     Else { $errorlabel.BackColor="Red";$errorlabel.ForeColor="Yellow";$errorlabel.Text = 'ERROR!: Unable to locate Path!'; return $FALSE }  }

Function Get-Folder ($initialDirectory=$pathtextbox.text) {

    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")|Out-Null

    $foldername = New-Object System.Windows.Forms.FolderBrowserDialog
    $foldername.Description = "Select a Folder"
    $foldername.SelectedPath = $initialDirectory

    if($foldername.Showdialog() -eq "OK")
    {
        $folder = $foldername.SelectedPath
    }
    else { $folder = $initialDirectory }
    $pathtextbox.text = $folder

    Check-Path $pathtextbox.text
}

Function Open-CSV ($csvpath) { & $csvpath '.\excel.exe' }

    ## Start building the windows form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Group Member CSV Tool'
    $form.Size = New-Object System.Drawing.Size(600,420)
    $form.StartPosition = 'CenterScreen'

    $cancelbutton = New-Object System.Windows.Forms.Button
    $cancelbutton.Location = New-Object System.Drawing.Point(265,345)
    $cancelbutton.Size = New-Object System.Drawing.Size(70,23)
    $cancelbutton.Text = 'Exit'
    $cancelbutton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $cancelbutton
    $form.Controls.Add($cancelbutton)

    $grouplabel = New-Object System.Windows.Forms.Label
    $grouplabel.Location = New-Object System.Drawing.Point(10,20)
    $grouplabel.Size = New-Object System.Drawing.Size(270,20)
    $grouplabel.Text = 'Select the Groups you would like a list for:'
    $form.Controls.Add($grouplabel)

    $pathlabel = New-Object System.Windows.Forms.Label
    $pathlabel.Location = New-Object System.Drawing.Point(300,20)
    $pathlabel.Size = New-Object System.Drawing.Size(270,20)
    $pathlabel.Text = 'Please Enter the Path to output the lists to:'
    $form.Controls.Add($pathlabel)

    $pathtextbox = New-Object System.Windows.Forms.TextBox
    $pathtextbox.Location = New-Object System.Drawing.Point(300,40)
    $pathtextbox.size = New-Object System.Drawing.Size(270,20)
    $pathtextbox.Text = "\\aetpdata\ourstuff\"
    $pathtextbox.Add_KeyDown({If ($_.KeyCode -eq "Enter")
            { Check-Path $pathtextbox.Text; }})
    $form.Controls.Add($pathtextbox)

    $checkbutton = New-Object System.Windows.Forms.Button
    $checkbutton.Location = New-Object System.Drawing.Point(299,65)
    $checkbutton.Size = New-Object System.Drawing.Size(75,20)
    $checkbutton.Text = 'Select Path'
    $checkbutton.Add_Click({Get-Folder})
    $form.Controls.Add($checkbutton)

    $clearbutton = New-Object System.Windows.Forms.Button
    $clearbutton.Location = New-Object System.Drawing.Point(398,65)
    $clearbutton.Size = New-Object System.Drawing.Size(75,20)
    $clearbutton.Text = 'Clear Form'
    $clearbutton.Add_Click({$pathtextbox.Text = "";$grouplistbox.ClearSelected();$errorlabel.text = "";$errorlabel.backcolor=""})
    $form.Controls.Add($clearbutton)

    $generatebutton = New-Object System.Windows.Forms.Button
    $generatebutton.Location = New-Object System.Drawing.Point(495,65)
    $generatebutton.Size = New-Object System.Drawing.Size(75,20)
    $generatebutton.Text = 'Create CSV'
    $generatebutton.Add_Click({
            If ($grouplistbox.SelectedIndex -ne -1) { GroupMember-To-CSV -groupsforoutput $grouplistbox.SelectedItems -urlpath $pathtextbox.Text }
            Else { $errorlabel.BackColor="Red";$errorlabel.ForeColor="Yellow";$errorlabel.Text = 'ERROR!: Please select a group!' }})
    $form.Controls.Add($generatebutton)

    $outputlabel = New-Object System.Windows.Forms.Label
    $outputlabel.Location = New-Object System.Drawing.Point(300,90)
    $outputlabel.Size = New-Object System.Drawing.Size(280,15)
    $outputlabel.Text = "Generated CSV files:"
    $form.Controls.Add($outputlabel)

    $outputlistbox = New-Object System.Windows.Forms.listBox
    $outputlistbox.Location = New-Object System.Drawing.Point(300,110)
    $outputlistbox.size = New-Object System.Drawing.Size(270,20)
    $outputlistbox.Height = 200
    $form.Controls.Add($outputlistbox)

    $openbutton = New-Object System.Windows.Forms.Button
    $openbutton.Location = New-Object System.Drawing.Point(495,312)
    $openbutton.Size = New-Object System.Drawing.Size(75,20)
    $openbutton.Text = 'Open CSV'
    $openbutton.Add_Click({Open-CSV $outputlistbox.SelectedItem})
    $form.Controls.Add($openbutton)

    $errorlabel = New-Object System.Windows.Forms.Label
    $errorlabel.Location = New-Object System.Drawing.Point(300,313)
    $errorlabel.Size = New-Object System.Drawing.Size(190,15)
    $errorlabel.Text = ""
    $form.Controls.Add($errorlabel)

    $grouplistbox = New-Object System.Windows.Forms.listBox
    $grouplistbox.Location = New-Object System.Drawing.Point(10,40)
    $grouplistbox.size = New-Object System.Drawing.Size(270,20)
    $form.Controls.Add($grouplistbox)

    $grouplistbox.SelectionMode = 'MultiExtended'

    ForEach ($group in $grouplist) { [void] $grouplistbox.Items.add($group) }

    $grouplistbox.Height = 300

    $form.Add_Shown({$grouplistbox.Select()})
    $result = $form.ShowDialog()