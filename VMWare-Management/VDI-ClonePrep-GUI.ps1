﻿#############################
## Created By Jake Hillman ##
#############################

## Suppress VM action progress bars
$ProgressPreference = "SilentlyContinue"

Import-Module ActiveDirectory, vmware.powercli
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

## Get list of computers in the Template OU
$templateOUComputers = (Get-ADComputer -Filter * -SearchBase "...DC=COM" -Properties Name | where { $_.Name -like "*GOLD*" } | Sort-Object -Property Name).Name

$infotext = "Clone Prep tool for use converting VDI Templates to Virtual Machine and booting them on a server`r`nso that Maintenance tasks can be completed and Templates can be automatically clone prepped and shut down.`r`n`r`nTo use this tool please ensure you have PowerCli installed on your local machine and click the login button to begin.`r`n`r`n"

$sepfolders = @( 'C$\',
                'C:\Program Files\Common Files\Symantec Shared\HWID\',
                'C$\ProgramData\Symantec\Symantec Endpoint Protection\PersistedData\',
                'C$\Users\All Users\Symantec\Symantec Endpoint Protection\PersistedData\',
                'C$\Windows\Temp' )
$sepuserfolder = 'C$\Users\'
$sepfiles = @( 'sephwid.xml', 'communicator.dat' )
$sepREGPath = 'HKLM:\SOFTWARE\WOW6432Node\Symantec\Symantec Endpoint Protection\SMC\SYLINK\SyLink'
$sepREGkeys = @( 'ForceHardwareKey','HardwareID','HostGUID' )

Function Clone-Prep {
    param ( [array]$computers, $credential )

    cmd.exe /c "ipconfig /flushdns" ## Clear DNS cache in case template IP mismatches from last clone prep shut down

    ## Stop the Symantec Master Service on each 
    ForEach ($computer in $computers) { Output -message "Stopping the Symantec service on $computer...`n"; Invoke-Command -ComputerName $computer -AsJob -ScriptBlock { cmd.exe /c "C:\Temp\ImagePrep\AutomatedClonePrep\smc.exe -stop" } > $NULL }

    ## Wait 60 seconds for the Symantec services to stop on the machines
    Start-Sleep 30

    ForEach ($computer in $computers) {
    
        Output -message "____________________________________________________________________________`n"
        Output -message "Starting Clone Prep Tasks on $computer...`n"
        Invoke-Command -ComputerName $computer -Credential $credential -ScriptBlock { cmd.exe /c "C:\Temp\ImagePrep\AutomatedClonePrep\clean-splunk-automated.bat" } > $NULL

        Start-Sleep 10

        Output -message "Completed Splunk cleaning...`r`n"
        Output -message "Removing Symantec files....`n"
        ## Remove files and RegKey items from Broadcom article for Symantec
        ForEach ($sepfile in $sepfiles) {
        
            ForEach ($sepfolder in $sepfolders) { If (Test-Path -Path "\\$computer\$sepfolder\$sepfile") { Remove-Item -Path "\\$computer\$sepfolder\$sepfile" -Confirm:$false } }

            $sepuserchildfolders = Get-ChildItem -Path "\\$computer\$sepuserfolder"

            ForEach ($sepuserchildfolder in $sepuserchildfolders) { If (Test-Path -Path "\\$computer\$sepuserchildfolder\AppData\Local\Temp\$sepfile") { Remove-Item -Path "\\$computer\$sepuserchildfolder\AppData\Local\Temp\$sepfile" -Confirm:$false } }
        }
        Output -message "Removing Symantec Reg Keys...`n"
        ForEach ($sepREGKey in $sepREGKeys) { Invoke-Command -ComputerName $computer -Credential $credential -ScriptBlock { Remove-ItemProperty -Path $using:sepREGPath -Name $using:sepREGKey -Confirm:$FALSE -Force -ErrorAction SilentlyContinue }  }
        Output -message "Completed removing Symantec items, releasing IP address and shutting down...`n"
        Invoke-Command -ComputerName $computer -Credential $credential -AsJob -ScriptBlock { cmd.exe /c "C:\Temp\ImagePrep\AutomatedClonePrep\final.bat" } > $NULL

        Output -message "$computer shut down and Clone Prepped`r`n" ##-ForegroundColor Green -BackgroundColor Gray
    }
    Output -message "`r`n"

    Start-Sleep 10

    ConvertTo-Template -machines $computers
    Output -message "Clone Prep tasks completed."
    Output -message "`r`n"
}

Function ConvertTo-Template {
    param ( [array]$machines )

    ForEach ($machine in $machines) {        

        If ((Get-VM -Name $machine).PowerState -eq "PoweredOn") { Stop-VM -VM (Get-VM -Name $machine) -Confirm:$false }

        Try { Output -message "Converting $machine to Template...`n"; Get-VM -Name $machine | Set-VM -ToTemplate -ErrorAction Stop -Confirm:$FALSE; Output -message "Successfully converted $machine to Template.`n" }
        Catch { Output -message "FAILED to convert $machine to Template!!!`n" }

        Output -message "`r`n"
        Update-Fields
    }
    Output -message "Convert to Template task completed.`r`n"
    Output -message "`r`n"
}

Function ConvertTo-VM {
    param ( [array]$machines )

    ForEach ($machine in $machines) {        
        
        Try { Output -message "Converting $machine to VM...`n"; Set-Template -Template $machine -ToVM -ErrorAction Stop -Confirm:$FALSE; Output -message "Successfully converted $machine to Virtual Machine.`r`n" }
        Catch { Output -message "FAILED to convert $machine to Virtual Machine!!!`n" }

        $onHost = (Get-VMHost -VM (Get-VM -name $machine)).Name

        If ($onHost -notin $hoststextbox.Items) { 
        
            Output -message "Migrating $machine to a host with available resources....`n"

            $n = ($hoststextbox.Items | Measure-Object).Count
            $seed = Get-Random -Maximum $n

            $newhost = $hoststextbox.Items[$seed]

            Get-Vm -Name $machine | Move-VM -Destination $newhost -Confirm:$false

            Output -Message "$machine migrated to $newhost, powering on...`r`n"; Output -message "`r`n"

            Start-VM -VM (Get-VM -name $machine)
            Update-Fields
        }
        Else { Output -message "Starting $machine on host $onHost...`r`n"; Output -message "`r`n"; Start-VM -VM (Get-VM -name $machine); Update-Fields }

        Output -message "`r`n"
    }
    Output -message "Convert to VM task completed."
    Output -message "`r`n"
}

Function Update-Templates {
    $templatelistbox.Items.Clear()
    $templates = (Get-Template).Name

    ForEach ($template in $templates) { [void] $templatelistbox.Items.add($template) }
}

Function Update-VMs {
    $vmlistbox.Items.Clear()
    ForEach ($templateComputer in $templateOUComputers) { If ((Get-VM -Name $templateComputer -ErrorAction SilentlyContinue) -ne $NULL) { [void] $vmlistbox.Items.Add($templateComputer) } }
}

Function Find-Hosts {
    $hoststextbox.Items.Clear()

    $vmhosts = Get-VMHost | where { $_.ConnectionState -notlike "Maintenance" } | Sort-Object -Property Name

    ForEach ($vmhost in $vmhosts) {
         $runningVMs = $vmhost | Get-VM | where { $_.PowerState -like "PoweredOn" }

         If (($runningVMs | Measure-Object).Count -lt 24 -and $vmhost -notlike "esxi-p40-66*" -and $vmhost -notlike "esxi-p40-69*") { $hoststextbox.Items.add($vmhost.Name) }
    }
}

Function Login-to-VCSA {
    param ( $credential )
    
    Output -message "Attempting to login to VCSA with provided credentials...`n"

    Try { $form.Activate(); Connect-VIServer -Server "vcsa-vdi-2" -Credential $credential -ErrorAction Stop; Output -message "Logged in successfully!`n"; $loginbutton.BackColor = "Green"; $loginbutton.Text = "Logged In"; Update-Fields; Button-Status -buttons $findbutton,$vmbutton,$templatebutton,$prepbutton -status $TRUE -color "LightGray"   }
    Catch { $form.Activate(); Output -message "Login to vcsa-vdi-2 FAILED!!!`r`nCheck credentials or vCenter permissions and try again.`n" }

    Output -message "`r`n"
    ##$logouttimer.Start()
}

Function Update-Fields { Update-Templates; Update-VMs; Find-Hosts }

Function Clear-Form {

    $hoststextbox.ClearSelected();$templatelistbox.Items.Clear();$outputlistbox.Text = $infotext;$hoststextbox.Items.Clear();$vmlistbox.Items.Clear()
    $errorlabel.text = "";$errorlabel.backcolor=""; $loginbutton.Text = "Login"
    Button-Status -buttons $findbutton,$vmbutton,$templatebutton,$prepbutton -status $FALSE -color "DarkGray"
    Button-Status -buttons $loginbutton -status $TRUE -color "LightGray"
    $cred = $NULL

    If ($global:DefaultVIServers -ne $NULL) { Disconnect-VIServer * -Confirm:$false -Force }
}

Function Button-Status {
    param ( [array]$buttons, [bool]$status, [string]$color )

    ForEach ($button in $buttons) {
        $button.Enabled = $status
        $button.BackColor = $color
    }
}

Function Output {
    param ( [string]$message )

    $outputlistbox.AppendText($message)
}

    ## Start building the windows form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'COMPASS Clone Prep Tool'
    $form.Size = New-Object System.Drawing.Size(691,610)
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.BackColor = "SlateGray"
    $form.StartPosition = 'CenterScreen'

    $formicon = New-Object system.drawing.icon ("\\aetpdata\ourstuff\_Hillman\Powershell Scripts\GE-Monogram.ico")
    $form.Icon = $formicon

    $cancelbutton = New-Object System.Windows.Forms.Button
    $cancelbutton.Location = New-Object System.Drawing.Point(315,545)
    $cancelbutton.Size = New-Object System.Drawing.Size(70,23)
    $cancelbutton.Text = 'Exit'
    $cancelbutton.BackColor = "LightGray"
    $cancelbutton.FlatStyle = "Flat"
    $cancelbutton.FlatAppearance.BorderColor = "Black"
    $cancelbutton.FlatAppearance.BorderSize = 1
    $cancelbutton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $cancelbutton.Add_Click({ If ($global:DefaultVIServers -ne $NULL) { Disconnect-VIServer * -Confirm:$false -Force } })
    $form.CancelButton = $cancelbutton
    $form.Controls.Add($cancelbutton)

    $templateslabel = New-Object System.Windows.Forms.Label
    $templateslabel.Location = New-Object System.Drawing.Point(10,20)
    $templateslabel.Size = New-Object System.Drawing.Size(190,20)
    $templateslabel.Text = 'VDI Templates to Convert:'
    $form.Controls.Add($templateslabel)

    $vmslabel = New-Object System.Windows.Forms.Label
    $vmslabel.Location = New-Object System.Drawing.Point(205,20)
    $vmslabel.Size = New-Object System.Drawing.Size(190,20)
    $vmslabel.Text = 'VMs Ready for Clone Prep:'
    $form.Controls.Add($vmslabel)

    $hostslabel = New-Object System.Windows.Forms.Label
    $hostslabel.Location = New-Object System.Drawing.Point(400,20)
    $hostslabel.Size = New-Object System.Drawing.Size(190,20)
    $hostslabel.Text = 'Available Hosts for VMs:'
    $form.Controls.Add($hostslabel)

    $hoststextbox = New-Object System.Windows.Forms.ListBox
    $hoststextbox.Location = New-Object System.Drawing.Point(400,40)
    $hoststextbox.size = New-Object System.Drawing.Size(190,20)
    $hoststextbox.BorderStyle = "FixedSingle"
    $hoststextbox.BackColor = "LightGray"
    $hoststextbox.SelectionMode = 'MultiExtended'
    $hoststextbox.Height = 130
    $form.Controls.Add($hoststextbox)

    $templatebutton = New-Object System.Windows.Forms.Button
    $templatebutton.Location = New-Object System.Drawing.Point(205,165)
    $templatebutton.Size = New-Object System.Drawing.Size(80,20)
    $templatebutton.Text = 'To Template'
    $templatebutton.FlatStyle = "Flat"
    $templatebutton.FlatAppearance.BorderColor = "Black"
    $templatebutton.FlatAppearance.BorderSize = 1
    $templatebutton.BackColor = "DarkGray"
    $templatebutton.Enabled = $false
    $templatebutton.Add_Click({If ($vmlistbox.SelectedIndex -ne -1) { ConvertTo-Template -machines $vmlistbox.SelectedItems }})
    $form.Controls.Add($templatebutton)

    $clearbutton = New-Object System.Windows.Forms.Button
    $clearbutton.Location = New-Object System.Drawing.Point(595,545)
    $clearbutton.Size = New-Object System.Drawing.Size(80,23)
    $clearbutton.Text = 'Reset Form'
    $clearbutton.FlatStyle = "Flat"
    $clearbutton.FlatAppearance.BorderColor = "Black"
    $clearbutton.FlatAppearance.BorderSize = 1
    $clearbutton.BackColor = "LightGray"
    $clearbutton.Add_Click({ Clear-Form })
    $form.Controls.Add($clearbutton)

    $vmbutton = New-Object System.Windows.Forms.Button
    $vmbutton.Location = New-Object System.Drawing.Point(10,165)
    $vmbutton.Size = New-Object System.Drawing.Size(80,20)
    $vmbutton.Text = 'To VM'
    $vmbutton.FlatStyle = "Flat"
    $vmbutton.FlatAppearance.BorderColor = "Black"
    $vmbutton.FlatAppearance.BorderSize = 1
    $vmbutton.BackColor = "DarkGray"
    $vmbutton.Enabled = $false
    $vmbutton.Add_Click({ If ($templatelistbox.SelectedIndex -ne -1) { ConvertTo-VM -machines $templatelistbox.SelectedItems } })
    $form.Controls.Add($vmbutton)

    $outputlabel = New-Object System.Windows.Forms.Label
    $outputlabel.Location = New-Object System.Drawing.Point(10,190)
    $outputlabel.Size = New-Object System.Drawing.Size(280,15)
    $outputlabel.Text = "Script Progress:"
    $form.Controls.Add($outputlabel)

    $outputlistbox = New-Object System.Windows.Forms.TextBox
    $outputlistbox.Location = New-Object System.Drawing.Point(10,210)
    $outputlistbox.size = New-Object System.Drawing.Size(664,20)
    $outputlistbox.Multiline = $TRUE
    $outputlistbox.ReadOnly = $TRUE
    $outputlistbox.AcceptsReturn = $TRUE
    $outputlistbox.ScrollBars = "Vertical"
    $outputlistbox.BorderStyle = "FixedSingle"
    $outputlistbox.BackColor = "LightGray"
    $outputlistbox.Text = $infotext
    $outputlistbox.Height = 330
    $form.Controls.Add($outputlistbox)

    $findbutton = New-Object System.Windows.Forms.Button
    $findbutton.Location = New-Object System.Drawing.Point(595,165)
    $findbutton.Size = New-Object System.Drawing.Size(80,20)
    $findbutton.Text = 'Query Fields'
    $findbutton.FlatStyle = "Flat"
    $findbutton.FlatAppearance.BorderColor = "Black"
    $findbutton.FlatAppearance.BorderSize = 1
    $findbutton.BackColor = "DarkGray"
    $findbutton.Enabled = $false
    $findbutton.Add_Click({ If ($global:DefaultVIServers -ne $NULL) {Update-Fields} Else { Output -message "Not connected to VCSA!`r`nPlease login first.`n" } })
    $form.Controls.Add($findbutton)

    $loginbutton = New-Object System.Windows.Forms.Button
    $loginbutton.Location = New-Object System.Drawing.Point(595,40)
    $loginbutton.Size = New-Object System.Drawing.Size(80,57)
    $loginbutton.Text = 'Login'
    $loginbutton.FlatStyle = "Flat"
    $loginbutton.FlatAppearance.BorderColor = "Black"
    $loginbutton.FlatAppearance.BorderSize = 1
    $loginbutton.BackColor = "LightGray"
    $loginbutton.Add_Click({ $global:cred = Get-Credential -Message "Enter VCSA Credentials:"; Login-to-VCSA -Credential $cred })
    $form.Controls.Add($loginbutton)

    $prepbutton = New-Object System.Windows.Forms.Button
    $prepbutton.Location = New-Object System.Drawing.Point(595,102)
    $prepbutton.Size = New-Object System.Drawing.Size(80,57)
    $prepbutton.Text = 'Clone Prep'
    $prepbutton.FlatStyle = "Flat"
    $prepbutton.FlatAppearance.BorderColor = "Black"
    $prepbutton.FlatAppearance.BorderSize = 1
    $prepbutton.BackColor = "DarkGray"
    $prepbutton.Enabled = $false
    $prepbutton.Add_Click({ If ($vmlistbox.SelectedIndex -ne -1) { Clone-Prep -computers $vmlistbox.SelectedItems -Credential $cred } })
    $form.Controls.Add($prepbutton)

    <# $logouttimer = New-Object System.Windows.Forms.Timer
    $logouttimer.Interval = 1000
    $countDown = 20
    $logouttimer.Add_Tick({ If ($countDown -lt 1) { Clear-Form; Output -message "`r`n"; Output -message "Logged out due to inactivity!`r`n"; $countDown = 20 } Else { $countDown-- } }) #>

    $templatelistbox = New-Object System.Windows.Forms.listBox
    $templatelistbox.Location = New-Object System.Drawing.Point(10,40)
    $templatelistbox.size = New-Object System.Drawing.Size(190,20)
    $templatelistbox.BorderStyle = "FixedSingle"
    $templatelistbox.BackColor = "LightGray"
    $templatelistbox.SelectionMode = 'MultiExtended'
    $templatelistbox.Height = 130
    $form.Controls.Add($templatelistbox)

    $vmlistbox = New-Object System.Windows.Forms.listBox
    $vmlistbox.Location = New-Object System.Drawing.Point(205,40)
    $vmlistbox.size = New-Object System.Drawing.Size(190,20)
    $vmlistbox.BorderStyle = "FixedSingle"
    $vmlistbox.BackColor = "LightGray"
    $vmlistbox.SelectionMode = 'MultiExtended'
    $vmlistbox.Height = 130
    $form.Controls.Add($vmlistbox)

    $form.Add_Shown({$templatelistbox.Select()})
    $result = $form.ShowDialog()