Import-Module ActiveDirectory

$computers = (Get-AdComputer -Filter * -SearchBase "OU=*,OU=*,DC=*,DC=*..." -SearchScope Subtree).Name
$domain = "col-dev.ge.com"
$failed = @()

ForEach ($computer in $computers) {

    If(!(Test-Connection -ComputerName $computer -Count 2 -Quiet -ErrorAction SilentlyContinue)) {
        Write-Warning "Unable to connect to $computer, logging and moving on..."; $failed += [pscusomobject]@{ NAME=$computer; Reason="Offline"}; Continue
    }
    Else {
        Copy-Item -Path "\\DC-1\c$\Windows\System32\WindowsPowerShell\v1.0\Modules\NFS" -Destination "\\$computer\c$\Windows\System32\WindowsPowerShell\v1.0\Modules\NFS" -force -Recurse
        If (!(Test-Path -Path "\\$computer\c$\Windows\System32\WindowsPowerShell\v1.0\Modules\NFS" -ErrorAction SilentlyContinue)) {
            Write-Warning "NFS module not found on $computer, logging and moving on..."; $failed += [pscustomobject]@{ NAME=$computer; Reason="Missing NFS Module"}; Continue }

        Try {
            Test-WSMan -ComputerName $computer -ErrorAction Stop | Out-Null
        } Catch {
            Write-Host -ForegroundColor Yellow "Enabling Winrm on $computer..."
            $winrmenable = 'wmic /node:"' + $computer + '" process call create "cmd.exe /c winrm quickconfig -quiet"'
            cmd.exe /c $winrmenable | Out-Null
            If ((Invoke-Command -ComputerName $computer { 1 } -ErrorAction Ignore) -ne 1) { Write-Warning "Enabling Winrm failed on $computer, logging and moving on..."; $failed += [pscustomobject]@{ NAME=$computer; Reason="Unable to enable Winrm" }
                Continue
            }
            Else { Write-Host -ForegroundColor Green "Successfully enabled Winrm on $computer, continuing..." }
        } Finally {
            Invoke-Command -ComputerName $computer -ScriptBlock {
                Enable-WindowsOptionalFeature -FeatureName ServicesForNFS-ClientOnly,ClientForNFS-Infrastructure -Online -NoRestart -WarningAction Ignore | Out-Null
                Import-Module NFS
                Set-NFSMappingStore -EnableADLookup $TRUE -ADDomainName $domain | Out-Null
            }
        }
    }
}

If ($failed -ne $NULL) { echo "`n`n"; Write-Warning "The following computers had errors:"; $failed }