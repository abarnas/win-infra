#!powershell
# 
# WANT_JSON
# POWERSHELL_COMMON
$params = Parse-Args $args;
 
If ($params.force) {
	$force = $params.force | ConvertTo-Bool
}
 
$result = New-Object psobject @{
	changed = $true
}

Restart-Computer -Force

Exit-Json $result; 
