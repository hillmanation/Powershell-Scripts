import-module ActiveDirectory

$ou = "" ## Dinstinguished Name of the OU you want to check
$filename = "" ## Path to where you want the CSV to go
$output = @() ## Define output array
                                                                                                                                                    ## Uncomment below to filter for WKS only ##
$computers = Get-ADComputer -filter * -Properties Name,OperatingSystem,DistinguishedName -SearchBase $ou -SearchScope Subtree | where { $_.OperatingSystem -like "*Windows*" -and $_.Name -like "WKS*"  } | Select-Object Name,DistinguishedName | Sort-Object -Property Name
$totalsystems = ($computers | Measure-Object).Count
$n = 0

ForEach ($computer in $computers) {
    ## Keep a progress bar on screen to show how many computers are left
    Write-Progress -Activity "Running Bitlocker Audit Script against $ou..." -Status "$n of $totalsystems completed" -PercentComplete (($n / $totalsystems) * 100)

    ## Get the Recovery Keys from AD and query the computer for TPM status and a list of local disks
    $computername = $computer.Name
    $adrecoverykeys = Get-AdObject -Filter 'objectClass -eq "msFVE-RecoveryInformation"' -SearchBase $computer.DistinguishedName -Properties msFVE-RecoveryPassword | Select-Object msFVE-RecoveryPassword
    Try { $tpmstatus = (Get-WmiObject Win32_Tpm -namespace root\CIMV2\Security\MicrosoftTpm -computername $computername).IsEnabled_InitialValue
          $drives = (Get-WmiObject win32_LogicalDisk -ComputerName $computername -Filter "DriveType=3").DeviceID }
    Catch { $tpmstatus, $drives = "Unable to Connect to Computer" }

    ## Step through each local drive
    ForEach ($drive in $drives) {
        ## manage-bde does not return the Recovery password information and Get-BitlockerVolume can only be run locally, so Invoke remote computer to run Get-BitlockerVolume for the RecoveryPassword and output it to a temp file
        ## and handle possible WinRM issues with Try/Catch
        Try { Invoke-Command -ComputerName $computername -ErrorAction Stop -ScriptBlock { (Get-BitlockerVolume -MountPoint $Using:drive).KeyProtector.RecoveryPassword | Out-File -FilePath "C:\Temp\DriveKey.txt" }
              $localkey = Get-Content "\\$computername\c$\Temp\DriveKey.txt" | where { $_ -ne "" }
        }
        Catch { $localkey = "WinRM Not Enabled" }

        ## Confirm that bitlocker is enabled on the drive
        $blcheck = manage-bde -status -computername $computername $drive
        If ($blcheck[13] -like "*Protection On*") { $bitlockerEnabled = "TRUE" }
        Else { $bitlockerEnabled = "FALSE" }

        ## Check if the locally reported key matches one that is present in AD or is missing
        If ($adrecoverykeys.'msFVE-RecoveryPassword' -contains $localkey -and $adrecoverykeys -ne $NULL) { $localkeyinAD = "TRUE" }
        ElseIf ($bitlockerEnabled -eq "FALSE") { $localkeyinAD = "FALSE" }
        ElseIf ($adrecoverykeys -ne $NULL) { $localkeyinAD = "UNKNOWN" }
        Else { $localkeyinAD = "FALSE" }

        ## Parse the above information into an output variable
        $output += [pscustomobject]@{ ComputerName = $computername; TPMEnabled = $tpmstatus; Drive = $drive; BitlockerEnabled = $bitlockerEnabled; RecoveryPassword = $localkey; KeyInAD = $localkeyinAD }
    }

    ## Remove the temp file on the remote computer
    Remove-Item -Path "\\$computername\c$\Temp\DriveKey.txt" -Force -Confirm:$FALSE -ErrorAction SilentlyContinue

    ## This needs to start NULL at the next computer or the If/Else statement won't work properly
    $adrecoverykeys = $NULL
    $n++
}

## Output the gathered information to a CSV
$output | Export-CSV -Path $filename -NoTypeInformation