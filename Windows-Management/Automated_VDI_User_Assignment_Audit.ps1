﻿Import-Module VMWare.PowerCLI,VMWare.Hv.Helper,ActiveDirectory,vmware.vimautomation.horizonview,vmware.vimautomation.core

$twomonthsago = (Get-Date).AddDays(-60)
$disabledusers = Get-ADObject -Filter 'ObjectClass -eq "User" -and whenChanged -ge $twomonthsago -and UserAccountControl -band 2' -Properties sAMAccountName

If ($disabledusers -ne $NULL) {

    #connect to HV server
    $hvserver = connect-hvserver "" -Domain "" -User your_account_name -Password 'your_password'

    ## Check for year and month folder in Log folder and create folders if needed
    $filedate = Get-Date -Format "_MM_dd_yyyy"
    $blank,$month,$day,$year = $filedate.split("_")
    $fullmonth = get-date -UFormat %B
    $rootfolder = ""
    $yearFolder = $rootfolder + $year + "\"

    If (!(Test-Path -Path $yearfolder)) { New-Item -Path $rootfolder -Name $year -ItemType Directory -Force | Out-Null }

    $monthfolder = $month + " - " + $fullmonth
    $logfolder = $yearfolder + "\" + $monthfolder + "\"

    If (!(Test-Path -Path $logfolder)) { New-Item -Path $yearfolder -Name $monthfolder -ItemType Directory -Force | Out-Null }

    $fileNameCSV = $logFolder + "VDI_User_Assignment_Audit_" + $fullmonth + ".csv"

    $server = Get-ADDomainController
    $disabledovertwomonths = @()
    $output = @()

    ##Find all disabled users whose accounts have been disabled greater than two months
    foreach ($disableduser in $disabledusers) {
       
           $whenDisabled = Get-ADReplicationAttributeMetadata $disableduser -Server $server -Properties UserAccountControl |
           Where-Object { $_.AttributeName -eq 'UserAccountControl' } | Select Object, LastOriginatingChangeTime
       
           If ($whenDisabled.LastOriginatingChangeTime -lt $twomonthsago) { 
                $properties = [pscustomobject]@{Name=[string]$disabledUser.Name;SamAccountName=[string]$disabledUser.sAMAccountName;DisabledOn=[string]$whenDisabled.LastOriginatingChangeTime}

                $disabledovertwomonths += $properties  
           }
    }

    ##Connect to the Horizon server and populate variables with user assignments
    $hvapi = $hvserver.ExtensionData
    $queryservice = New-Object 'VMware.Hv.QueryServiceService'
    $querydefinition = New-Object 'VMware.Hv.QueryDefinition'
    $querydefinition.queryEntityType = 'MachineNamesView'
    $sessions = $queryservice.QueryService_Query($hvapi,$querydefinition)
    $sessionsobject = $sessions.Results

    ##Check the user assignments for accounts that are in the $disabledovertowmonths variable, if found remove the assignments for that user
    ForEach ($session in $sessionsobject) {

        $username = ""
        $username = $session.namesdata.Username
        If ($username -ne $NULL) { $blank, $username = $username.split('\') }

        If ($username -ne $NULL -and (Get-ADUser -Identity $username -Properties Enabled).Enabled -eq $FALSE) { 

            $machine = ""
            $machine = $session.base.name

            If ($username -in $disabledovertwomonths.sAMAccountName) { echo "Removing $username assignment from $machine...."
                ##Store Machine Service as a variable
                $machineservice = New-Object vmware.hv.machineservice
                ##Get the machine ID and store it to a variable
                $machineID = (Get-HvMachine -MachineName $machine).id
                ##Read the properties of the machine service in the machine ID variable and save to a variable
                $machineinfohelper = $machineservice.read($hvapi, $machineid)
                ##Set user info to $NULL, NOTE THIS DOES NOT APPLY it only sets the value being held in the $machineinfohelper variable, the next step applies it
                $machineinfohelper.getBaseHelper().setuser($NULL)
                ##Update the machine service with the new information
                $machineservice.update($hvapi, $machineinfohelper)

                $output = [pscustomobject]@{ samAccountName = $username; AssignmentRemoved = $machine; DateRemoved=(Get-Date -Format "MM/dd/yyyy") }
                $output | Export-CSV -Path $filenameCSV -NoTypeInformation -Append
            }
        }
    }
    ##Disconnect the Horizon server session
    $hvserver | Disconnect-HVServer -Force -Confirm:$FALSE
}