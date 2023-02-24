import-module vmware.powercli
$output = @()

##Vaiable to hold each vCenter server name
$vcsa = ''

##Connect to each vCenter server using an account that has permission to do so (don't save script with the password in in)
$vcsa | % { Connect-VIServer $_ -User 'your_account_name' -Password 'your_password' }

##Populate a list of all hosts from the entered vCenter servers
$vmhosts = Get-VMHost | Sort-Object

ForEach ($vmhost in $vmhosts) {

    $vmhostinfo = ($vmhost | Get-ESXCli).hardware.platform.get()
    
    $output += [pscustomobject]@{ HostName = $vmhost.Name; Manufacturer = $vmhostinfo.VendorName; Model = $vmhostinfo.ProductName; SerialNumber = $vmhostinfo.SerialNumber }
}

Disconnect-VIServer * -Confirm:$false