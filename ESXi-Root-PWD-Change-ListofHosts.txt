#############################
## Created By Jake Hillman ##
#############################

## Import the PowerCLI module - You will need to install this if you do not currently have it - U:\Powershell\PowerCLI
Import-Module VmWare.PowerCLI

## Set the invalid cert action and set TLS to 1.2 or higher
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::tls12

$vCenterServers = 'vcsa-svr-1','vcsa-vdi-2' ## <==== Enter the VCSA server DNS resolvable names here
$failed = @()
$computers = 'esxi-p40-47'

ForEach ($vCenterServer in $vCenterServers) {
    ## Connects to VCSA Host using current user's credentials
    Connect-VIServer $vCenterServer
}

Write-Host "`r`nPlease enter the current credentials of the hosts:`r`n" -Foregroundcolor Yellow

$CurrentCreds = Get-Credential ## Get current password for all of the hosts

Write-Host "Please enter the updated credentials for the hosts:`r`n" -ForegroundColor Yellow

$NewCreds = Get-Credential ## Get the password you are attempting to set on all of the hosts

ForEach ($computer in $computers) {
    
    ## Connect to each host and update the root password to the newly entered one
    Connect-VIServer -server $computer -Credential $CurrentCreds -NotDefault
    Set-VMHostAccount -server $computer -UserAccount root -Password $NewCreds.GetNetworkCredential().Password
}

Disconnect-VIServer -Server * -Confirm:$false