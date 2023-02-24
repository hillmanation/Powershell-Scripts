$drives =  '',''
$logdate = Get-Date -Format "_MM_dd_yyyy"
$log = "\Script Output\"
$start = Get-Date

function Get-FilesandFolders {

param( [string]$ITEM, [string]$share )

        $directories = get-childitem $ITEM -Directory | select FullName
        $files = get-childitem $ITEM -File | select Name,*time,Length,FullName
        
        ForEach ($file in $files) {
                
                $year = ($file.LastAccessTime | Get-Date -UFormat %Y)
                $month = ($file.LastAccessTime | Get-Date -UFormat %B)

                $outlog = $log + $share + '\' + $year + "\" + $month + $logdate + ".csv"

                If (!(Test-Path $log\$share\$year)) { New-Item -Path $log\$share -Name $year -ItemType "directory" | Out-Null }
                
                $file | Export-CSV $outlog -Append -NoTypeInformation
        }
        
        If ($directories -ne $NULL) {

            ForEach ($dir in $directories) {
        
                    Get-FilesandFolders -ITEM $dir.FullName -share $share

        } }
}

ForEach ($drive in $drives) {

    Get-FilesandFolders -ITEM $drive -share $drive

}

$end = Get-Date
$elapsed = (($end - $Start).TotalHours)

"Script finished in $elapsed hours..." | Add-Content "\Script Output\fileaccessedscript_runtime.txt"