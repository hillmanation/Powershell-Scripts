$prefix = "1.2.840.113556.1.8000.2254"

$GUID = [System.GUID]::NewGUID().ToString()

$parts=@()

$parts+=[UInt64]::Parse($guid.substring(0,4),"AllowHexSpecifier")

$parts+=[UInt64]::Parse($guid.substring(4,4),"AllowHexSpecifier")

$parts+=[UInt64]::Parse($guid.substring(9,4),"AllowHexSpecifier")

$parts+=[UInt64]::Parse($guid.substring(14,4),"AllowHexSpecifier")

$parts+=[UInt64]::Parse($guid.substring(19,4),"AllowHexSpecifier")

$parts+=[UInt64]::Parse($guid.substring(24,6),"AllowHexSpecifier")

$parts+=[UInt64]::Parse($guid.substring(30,6),"AllowHexSpecifier")

$oid = [string]::Format("{0}.{1}.{2}.{3}.{4}.{5}.{6}.{7}",$prefix,$parts[0],$parts[1],$parts[2],$parts[3],$parts[4],$parts[5],$parts[6])

$oid