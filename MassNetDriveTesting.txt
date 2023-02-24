$drives = 'K','M','O','P','Q','R','S','T','U','V','Y'
$startTime = Get-Date


DO
{

    ForEach ( $drive in $drives) {
            If (!(Test-Path -Path ($drive + ":/"))) { $stop = $True; Break }
            $now = Get-Date -Format "HH:mm:ss"
            echo "Tested drive $drive, currently connected at $now.`n`n"
            ##Start-Sleep -Seconds 1
    }


} Until ( $stop -eq $True  )

$now = Get-Date -Format "HH:mm:ss"
$endTime = Get-Date
$elapsed = (($endTime - $startTime).totalSeconds)

echo "`n`nDrive $drive lost connection at $now.`n`nIt was active for $elapsed seconds."

$stop = $NULL