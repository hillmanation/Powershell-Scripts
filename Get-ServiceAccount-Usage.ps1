$account = "svc_commvault"

$date = (Get-Date).AddDays(-7)
$date = $date.ToString("M/dd/yyyy")

get-eventlog -logname "security" -ComputerName DC-1 -after $date | where {$_.message.contains("$account") -and $_.EventID -eq "4624"} | select -last 500

#$logs[0..5]