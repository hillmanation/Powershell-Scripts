import-module vmware.powercli ##This needs to be installed on the machine you are running this from

##Vaiable to hold each vCenter server name
$vcsa = ''
$failed = @()

##Connect to each vCenter server using an account that has permission to do so (don't save script with the password in in)
$vcsa | % { Connect-VIServer $_ -User 'your_account_name' -Password 'your_password' }
echo "`r`n"

##Populate a list of all hosts from the entered vCenter servers
$scope = Get-VMHost | Sort-Object

ForEach ($ESXIhost in $scope) { 

    ##Place host into lockdown mode (EnterLockdownMode()) or disable lockdown mode (ExitLockdownMode())
    (Get-VMHost $esxihost.Name | Get-View).EnterLockDownMode()
    Write-Host "Host $esxihost is now" (Get-vmhost $ESXIhost.Name).ExtensionData.Config.Lockdownmode

    ##Check if the host is in lockdown mode
    If ((Get-vmhost $ESXIhost.Name).ExtensionData.Config.Lockdownmode -eq 'lockdownDisabled') { $failed += $ESXIhost.Name }
}

##Exit all host/vcsa connections
Disconnect-VIServer * -Confirm:$false