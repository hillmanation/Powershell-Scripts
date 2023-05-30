Import-Module ActiveDirectory

$computers = (Get-AdComputer -Filter * -SearchBase "OU=*,OU=*,DC=*,DC=*..." -SearchScope Subtree).Name
$domain = "col-dev.ge.com"
$nfspath = "c$\Windows\System32\WindowsPowerShell\v1.0\Modules\NFS"
$failed = @()
$total = $computers.Count
$start = Get-Date
$progress = 0
$timespan = [timespan]::FromMinutes($total)
$estimated = ("{0:hh\:mm\:ss}" -f $timespan)

function Write-ProgressHelper {
    param(
        [int]$StepNumber,
        [string]$Message,
        [int]$remaining
    )
    
    Write-Progress -Activity 'Installing NFS Dependancies' -CurrentOperation $Message -PercentComplete (($StepNumber / $total) * 100) -SecondsRemaining $remaining
}

Write-Host -ForegroundColor Green "Starting tasks on $total computers at $start, estimated time to completion $estimated..."

ForEach ($computer in $computers) {
    $progress++
    $elapsed = ("{0:hh\:mm\:ss}" -f [timespan]::FromSeconds(((Get-Date) - $start).TotalSeconds))
    $average = ((Get-Date) - $start).TotalSeconds/$progress
    $timeremaining = ([timespan]::FromSeconds($average * ($total - $progress))).TotalSeconds

    Write-ProgressHelper -StepNumber $progress -Message "Running tasks on $computer...`tTotal Elapsed Time: $elapsed" -Remaining $timeremaining

    If(!(Test-Connection -ComputerName $computer -Count 2 -Quiet -ErrorAction SilentlyContinue)) {
        Write-Warning "Unable to connect to $computer, logging and moving on..."; $failed += [pscustomobject]@{ NAME=$computer; Reason="Offline"}; Continue
    }
    Else {
        Copy-Item -Path "\\DC-1\$nfspath" -Destination "\\$computer\$nfspath" -force -Recurse
        If (!(Test-Path -Path "\\$computer\$nfspath" -ErrorAction SilentlyContinue)) {
            Write-Warning "NFS module not found on $computer, logging and moving on..."; $failed += [pscustomobject]@{ NAME=$computer; Reason="Missing NFS Module"}; Continue }

        Try {
            Test-WSMan -ComputerName $computer -ErrorAction Stop | Out-Null
        } Catch {
            Write-Host -ForegroundColor Yellow "Enabling Winrm on $computer, the error output in this step is expected..."
            $winrmenable = 'wmic /node:"' + $computer + '" process call create "cmd.exe /c winrm quickconfig -quiet"'
            cmd.exe /c $winrmenable | Out-Null
            If ((Invoke-Command -ComputerName $computer { 1 } -ErrorAction Ignore) -ne 1) { Write-Warning "Enabling Winrm failed on $computer, logging and moving on..."
                $failed += [pscustomobject]@{ NAME=$computer; Reason="Unable to enable Winrm" }
                Continue
            }
            Else { Write-Host -ForegroundColor Green "Successfully enabled Winrm on $computer, continuing..." }
        } Finally {
            Invoke-Command -ComputerName $computer -ScriptBlock {
                Enable-WindowsOptionalFeature -FeatureName ServicesForNFS-ClientOnly,ClientForNFS-Infrastructure -Online -NoRestart -WarningAction Ignore | Out-Null
                Import-Module NFS
                Set-NFSMappingStore -EnableADLookup $TRUE -ADDomainName $using:domain | Out-Null
            }
        }
    }
}

$end = Get-Date

Write-Host -ForegroundColor Green -BackgroundColor Black "`nTasks completed at $end, total elapsed time $elapsed."

If ($failed -ne $NULL) { echo "`n`n"; Write-Warning "The following computers had errors:"; $failed }