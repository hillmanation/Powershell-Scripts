Import-Module ActiveDirectory

$homefolders = Import-CSV -Path "\\path\to\exported-uid.csv"

ForEach ($name in $homefolders) {
    Try { 
        Get-ADUser -Identity $($name.Name) -Properties uidNumber,gidNumber,ScriptPath -ErrorAction Stop | Out-Null

        Set-ADUser -identity $($name.Name) -Replace @{uidNumber=$name.UID; gidNumber=$name.GID; scriptpath="map-unix-home.bat"} -ErrorAction Stop

        If ((Get-ADUser -Identity $($name.Name) -Properties uidNumber,gidNumber,ScriptPath -ErrorAction Stop |
            Select-Object uidNumber,gidNumber,ScriptPath) -match [pscustomobject]@{ uidNumber=$name.UID; gidNumber=$name.GID; ScriptPath="map-unix-home.bat" }) {
            
            Write-Host -ForegroundColor Green "User $($name.Name) UID, GID, Logon Script Path updated successfully!!!"
        }
    } Catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
    { Write-Warning "User not found with SamAccountName $($name.Name), moving on..."; Continue }
    Catch { Write-Warning "Error occurred on user $($name.Name) with details:"; Write-Host -ForegroundColor Red "`t$($Error[0].Exception.Message)"; Continue }
}