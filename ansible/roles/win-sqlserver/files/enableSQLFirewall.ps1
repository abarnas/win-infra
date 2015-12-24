#------------------------------------------------------------------------------------------------------------------
# Script  : enableFirewallSQL.ps1
#------------------------------------------------------------------------------------------------------------------

# Parameters
[CmdletBinding()]
Param(
	[Parameter(Mandatory)]
	[psobject]$SQLServer=$null
)

#------------------------------------------------------------------------------------------------------------------
# Enable the SQL firewall ports
function enableFirewallSQL
{
	$instancename = $SQLServer.config.instancename
	$instanceports = $SQLServer.config.instanceports
	
	try
	{
		# Configure standard SQL ports
		if (-Not(Get-NetFirewallRule -DisplayName "SQL Server" -ErrorAction SilentlyContinue)) {
			New-NetFirewallRule -DisplayName "SQL Server" -Direction inbound -Protocol TCP -LocalPort $instanceports -Action allow
		} else {
			Set-NetFirewallRule -DisplayName "SQL Server" -Direction inbound -Protocol TCP -LocalPort $instanceports -Action allow
		}
		
		if (-Not(Get-NetFirewallRule -DisplayName "SQL Admin Connection" -ErrorAction SilentlyContinue)) {
			New-NetFirewallRule -DisplayName "SQL Admin Connection" -Direction inbound -Protocol TCP -LocalPort 1434 -Action allow
		} else {
			Set-NetFirewallRule -DisplayName "SQL Admin Connection" -Direction inbound -Protocol TCP -LocalPort 1434 -Action allow
		}
		
		if (-Not(Get-NetFirewallRule -DisplayName "SQL AlwaysOn Replication " -ErrorAction SilentlyContinue)) {
			New-NetFirewallRule -DisplayName "SQL AlwaysOn Replication" -Direction inbound -Protocol TCP -LocalPort 5022 -Action allow
		} else {
			Set-NetFirewallRule -DisplayName "SQL AlwaysOn Replication" -Direction inbound -Protocol TCP -LocalPort 5022 -Action allow
		}
		
		if (-Not(Get-NetFirewallRule -DisplayName "SQL Database Management" -ErrorAction SilentlyContinue)) {
			New-NetFirewallRule -DisplayName "SQL Database Management" -Direction inbound -Protocol UDP -LocalPort 1434 -Action allow
		} else {
			Set-NetFirewallRule -DisplayName "SQL Database Management" -Direction inbound -Protocol UDP -LocalPort 1434 -Action allow
		}

		if (-Not(Get-NetFirewallRule -DisplayName "SQL Service Broker" -ErrorAction SilentlyContinue)) {
			New-NetFirewallRule -DisplayName "SQL Service Broker" -Direction inbound -Protocol TCP -LocalPort 4022 -Action allow
		} else {
			Set-NetFirewallRule -DisplayName "SQL Service Broker" -Direction inbound -Protocol TCP -LocalPort 4022 -Action allow
		}
		
		if (-Not(Get-NetFirewallRule -DisplayName "SQL Debugger/RPC" -ErrorAction SilentlyContinue)) {
			New-NetFirewallRule -DisplayName "SQL Debugger/RPC" -Direction inbound -Protocol TCP -LocalPort 135 -Action allow
		} else {
			Set-NetFirewallRule -DisplayName "SQL Debugger/RPC" -Direction inbound -Protocol TCP -LocalPort 135 -Action allow
		}
		
		if (-Not(Get-NetFirewallRule -DisplayName "SQL Analysis Services" -ErrorAction SilentlyContinue)) {
			New-NetFirewallRule -DisplayName "SQL Analysis Services" -Direction inbound -Protocol TCP -LocalPort 2383 -Action allow
		} else {
			Set-NetFirewallRule -DisplayName "SQL Analysis Services" -Direction inbound -Protocol TCP -LocalPort 2383 -Action allow
		}
		
		if (-Not(Get-NetFirewallRule -DisplayName "SQL Browser" -ErrorAction SilentlyContinue)) {
			New-NetFirewallRule -DisplayName "SQL Browser" -Direction inbound -Protocol TCP -LocalPort 2382 -Action allow
		} else {
			Set-NetFirewallRule -DisplayName "SQL Browser" -Direction inbound -Protocol TCP -LocalPort 2382 -Action allow
		}
		
		if (-Not(Get-NetFirewallRule -DisplayName "HTTP" -ErrorAction SilentlyContinue)) {
			New-NetFirewallRule -DisplayName "HTTP" -Direction inbound -Protocol TCP -LocalPort 80 -Action allow
		} else {
			Set-NetFirewallRule -DisplayName "HTTP" -Direction inbound -Protocol TCP -LocalPort 80 -Action allow
		}

		if (-Not(Get-NetFirewallRule -DisplayName "SSL" -ErrorAction SilentlyContinue)) {
			New-NetFirewallRule -DisplayName "SSL" -Direction inbound -Protocol TCP -LocalPort 443 -Action allow
		} else {
			Set-NetFirewallRule -DisplayName "SSL" -Direction inbound -Protocol TCP -LocalPort 443 -Action allow
		}

		if (-Not(Get-NetFirewallRule -DisplayName "SQL Server Browse Button" -ErrorAction SilentlyContinue)) {
			New-NetFirewallRule -DisplayName "SQL Server Browse Button" -Direction inbound -Protocol UDP -LocalPort $instanceports -Action allow
		} else {
			Set-NetFirewallRule -DisplayName "SQL Server Browse Button" -Direction inbound -Protocol UDP -LocalPort $instanceports -Action allow
		}
	}
	catch
	{
		$linenr = $_.InvocationInfo.ScriptLineNumber
		$line = $_.InvocationInfo.Line
		Throw "Error enabling firewall at line $linenr - $line. $($_.Exception.Message)"
	}
}

#----------------------------------------------------------------------------------------------
# Setup error handling.
$VerbosePreference = "Continue"

Trap
{
    Write-Error $_
    Exit 1
}
$ErrorActionPreference = "Stop"

#----------------------------------------------------------------------------------------------
# Main
#----------------------------------------------------------------------------------------------

# Make sure we run as admin            
$usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()            
$IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                               
if (-not($IsAdmin))            
{            
	Write-Warning "Must run powerShell as Administrator to perform these actions"           
	return           
}

# Set firewall rules
enableFirewallSQL



