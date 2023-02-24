Import-Module VmWare.PowerCLI

#Requires -version 3
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::tls12

$vCenterServers = 'vcsa-svr-1','vcsa-vdi-2'
$updatedbanner = [string](Get-Content -path "\DCSA Authorized Warner Banner.txt")
$failed = @()

ForEach ($vCenterServer in $vCenterServers) {
    #Connects to VCSA Host using credentials
    Connect-VIServer $vCenterServer
}

$datacenters = (Get-Datacenter).Name

ForEach ($datacenter in $datacenters) { $hosts += (Get-Datacenter $datacenter | Get-VMHost).Name }

ForEach ($ESXiHost in $hosts) {

    Get-VMHost $ESXiHost|Get-AdvancedSetting -Name Annotations.WelcomeMessage|Set-AdvancedSetting -Value $updatedbanner -Confirm:$false
    If ((Get-VMHost $ESXiHost|Get-AdvancedSetting -Name Annotations.WelcomeMessage).Value -eq $updatedbanner) { echo "Banner updated successfully on $esxihost..." }
    Else { Write-Warning "Banner not updated on $esxihost..."; $failed += $esxihost }
    Get-VMHost $ESXiHost|Get-AdvancedSetting -Name Config.Etc.issue|Set-AdvancedSetting -Value $updatedbanner -Confirm:$false
}