import-module vmware.powercli

$vcsas = ''
$output = @()

$vcsas | % { Connect-VIServer $_ -User 'your_account_name' -Password 'your_password' }

$scope = Get-VMHost | Sort-Object

ForEach ($ESXIhost in $scope) { 
    $properties = [pscustomobject]@{Hostname=[string]$ESXIhost; LockdownModeStatus=(Get-vmhost $ESXIhost).ExtensionData.Config.Lockdownmode}
    $output += $properties
}

$output | FT -AutoSize

Disconnect-VIServer * -confirm:$false