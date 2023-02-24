import-module activedirectory

$computers = (Get-ADComputer -filter * -Properties Name,OperatingSystem | Select-Object Name,OperatingSystem | where { $_.OperatingSystem -like "*Windows*" -and $_.Name -like "*VDI*" -and $_.Name -notlike "*GOLD*" } | Sort-Object -Property Name).Name
$table=@()
$totalreclaimed = 0

ForEach ($computer in $computers) { 
    
        $diskbefore = Get-WmiObject Win32_LogicalDisk -ComputerName $computer -Filter "DeviceId='C:'" | Select-Object Size,FreeSpace
        $free = [Math]::Round($diskbefore.FreeSpace/1GB,2)
        $table += [pscustomobject]@{Computer=$computer; FreeSpace=$free; ReclaimedSpace=""; TotalReclaimed=""}

        Clear-EventLog -LogName Security -ComputerName $computer

        $diskafter = Get-WmiObject Win32_LogicalDisk -ComputerName $computer -Filter "DeviceId='C:'" | Select-Object Size,FreeSpace
        $freeafter = [Math]::Round($diskafter.FreeSpace/1GB,2)
        $reclaimed = $freeafter - $free
        $totalreclaimed += $reclaimed
        $table += [pscustomobject]@{Computer="$computer Log Removed"; FreeSpace=$freeafter; ReclaimedSpace=$reclaimed; TotalReclaimed=$totalreclaimed}
}

$table | FT -AutoSize