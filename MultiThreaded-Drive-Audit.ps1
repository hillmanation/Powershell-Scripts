$rootfolder = '\\path\to\searchdirectory'
$logfolder = '\\path\to\log\folder'
$date = Get-Date
$age = 365
$jobs = @()
$MaxThreads = 8

Function MultiThread-Search {
    Param($directory, $log)
    $folder = $directory.Name

    $job = Start-Job -ScriptBlock {
        gci $using:directory.FullName -Recurse |
        where { (New-TimeSpan -start $_.LastWriteTime -end $using:date).Days -gt $using:age -and (New-TimeSpan -start $_.CreationTime -end $using:date).Days -gt $using:age } |
        Select-Object FullName,LastWriteTime,LastAccessTime,CreationTime |
        Export-CSV $using:log\$using:folder-Drive-Audit.csv -NoTypeInformation -Append
    }

    return [pscustomobject]@{ ID=$job.Id; FOLDER=$folder }
}

"Starting script at $date" | Out-Host

$childfolders = gci $rootfolder | Select-Object FullName,LastWriteTime,LastAccessTime,CreationTime,Name,Attributes

ForEach ($childfolder in $childfolders) {
    If ($childfolder.Attributes -like "*Archive*" -and (New-TimeSpan -start $childfolder.LastWriteTime -end $date).Days -gt $age -and (New-TimeSpan -start $childfolder.CreationTime -end $date).Days -gt $age) {
        $childfolder | Select-Object FullName,LastWriteTime,LastAccessTime,CreationTime |
        Export-CSV $logfolder\Drive-Audit.csv -NoTypeInformation -Append
    }
    Elseif ($childfolder.Attributes -like "*Directory*") {
        $wait = $TRUE
        Do {
            $waitcheck = @()
            ForEach ($job in $jobs) {
                $waitcheck += Get-Job -ID $job.ID
            }
            $runcount = ($waitcheck.State -match "Running").Count
            If ($runcount -lt $MaxThreads -or $jobs -eq "") { $wait = $FALSE }
            Else { cls; "$runcount threads reached, waiting for a job to complete before registering a new one..." | Out-Host; Start-Sleep 2 }
        } while ($wait -eq $TRUE)
        $jobs += MultiThread-Search -directory $childfolder -log $logfolder
    }
}

Do {
    $exit = 0
    "Checking status of remaing jobs..." | Out-Host
    ForEach ($job in $jobs) {
        $id = $job.ID
        $jobname = $job.FOLDER
        $jobcheck = Get-Job -ID $id
        $status = $jobcheck.State
        If ($status -ne "Completed") { "Job #$id $jobname status $status..." | Out-Host }
        ElseIf ($status -eq "Completed") { $exit++ }
        ElseIf ($status -eq "Failed") { Write-Warning $jobcheck.ChildJobs[0].JobStateInfo.Reason.Message; $exit++ }
    }
    Start-Sleep 2
    cls
} while ($exit -lt $jobs.Count)

$end = Get-Date
$elapsed = ($end - $date)

"Elapsed $elapsed" | Out-Host

"Consolidating files at $end..." | Out-Host

$files = (gci $logfolder -File).FullName | where { $_ -ne "$logfolder\Drive-Audit.csv" } | Sort-Object -Property FullName

$filejob = Start-Job -ScriptBlock { 
    ForEach ($file in $using:files) {
        $import = Import-CSV $file
        If ($import -ne $NULL) { $import | Export-CSV $using:logfolder\Drive-Audit.csv -NoTypeInformation -Append }
    }
}
$filejobID = $filejob.ID

"`nWriting to consolidated file in the background, please monitor the progress here: $logfolder\Drive-Audit.csv" | Out-Host
Write-Host -ForegroundColor Green "Check progress via 'Get-Job -ID $filejobID'"

$end = Get-Date
$elapsed = ($end - $date)

"`nTotal Elapsed time $elapsed" | Out-Host