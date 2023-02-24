$vdis = "Win10-LTSC" ##(Get-AdComputer -filter * | Where { $_.Name -like "*lynn*" }).Name ##'vdi-fett-041','vdi-fett-042','vdi-fett-043','vdi-fett-044','vdi-fett-045'

ForEach ($vdi in $vdis) {

    If (Test-Connection -ComputerName $vdi -Count 1 -Quiet) { echo "Sending reboot command to $vdi..."; Invoke-Command -ComputerName $vdi -ScriptBlock { cmd.exe /c "shutdown -r now" } }
    Else { Write-Warning "Unable to connect to $vdi!!!" }
}
echo "Waiting 300 seconds to send second reboot command..."
Sleep 300

ForEach ($vdi in $vdis) {

    If (Test-Connection -ComputerName $vdi -Count 1 -Quiet) { echo "Sending second reboot command to $vdi..."; Invoke-Command -ComputerName $vdi -ScriptBlock { cmd.exe /c "shutdown -r now" } }
    Else { Write-Warning "Unable to connect to $vdi!!!" }
}

echo "Waiting 300 seconds to send second reboot command..."
Sleep 300

ForEach ($vdi in $vdis) {

    If (Test-Connection -ComputerName $vdi -Count 1 -Quiet) { echo "Sending third reboot command to $vdi..."; Invoke-Command -ComputerName $vdi -ScriptBlock { cmd.exe /c "shutdown -r now" } }
    Else { Write-Warning "Unable to connect to $vdi!!!" }
}