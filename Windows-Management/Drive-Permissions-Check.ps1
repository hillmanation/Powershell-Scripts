#############################
## Created By Jake Hillman ##
#############################

$folderPath = Get-ChildItem -Directory -Path "V:\" -Recurse -Force
$output = @()

ForEach ($folder in $folderpath) {
    $acl = Get-Acl -Path $folder.FullName
    ForEach ($access in $acl.Access) {
        $permissions = [string]$access.AccessControlType + ' - ' + [string]$access.FileSystemRights
        $properties = [pscustomobject]@{Folder= [string]$folder.Fullname;GroupOrUser=[string]$access.IdentityReference;Permissions=$permissions;Inherited=[string]$access.IsInherited}
        $output += New-Object -TypeName PSObject $properties }
}

$output | Export-Csv "//aetpdata/ourstuff/_Hillman/Script Output/VdriveAccess-March2020.csv" -Append -NoTypeInformation

$output = $NULL