import-module activedirectory

$computers = (Get-ADComputer -filter * -Properties OperatingSystem | where { $_.OperatingSystem -like "Windows*" -and $_.OperatingSystem -notlike "*Server*" -and $_.Name -notlike "*GOLD*" } | Sort-Object -Property Name).Name

$keys = "HKLM\SOFTWARE\CLasses\Installer\Features\2622A2495890D204EB4BA84D1FE67EE6", "HKLM\SOFTWARE\CLasses\Installer\Products\2622A2495890D204EB4BA84D1FE67EE6"
$output = @()
$fn = 0
$pn = 0

ForEach ($computer in $computers) { 
    
    ForEach ($key in $keys) {

        $regkey = reg query "\\$computer\$key"
        If ($regkey -ne $NULL) { $keyexists = $TRUE }
        Else { $keyexists = $FALSE }

        If ($key -like "*Features*") { $featureskey = $keyexists; If ($keyexists -eq $TRUE) { $fn++ } }
        If ($key -like "*Products*") { $productskey = $keyexists; If ($keyexists -eq $TRUE) { $pn++ } }
    }

    $output += [pscustomobject]@{ ComputerName = $computer; FeaturesKey=$featureskey; ProductsKey=$productskey }

}

($computers | Measure-Object).Count
$fn
$pn