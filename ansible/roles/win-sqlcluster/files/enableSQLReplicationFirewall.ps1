#------------------------------------------------------------------------------------------------------------------
# Script  : enableFirewallSQL.ps1
#------------------------------------------------------------------------------------------------------------------

# Parameters
[CmdletBinding()]
Param(
	[Parameter(Mandatory)]
	[psobject]$Cluster=$null
)

#------------------------------------------------------------------------------------------------------------------
# Enable the SQL firewall ports
function enableFirewallSQL
{
	try
	{
		# Configure SQL endpoint replication port
		if (-Not(Get-NetFirewallRule -DisplayName "SQL AlwaysOn Replication" -ErrorAction SilentlyContinue)) {
			New-NetFirewallRule -DisplayName "SQL AlwaysOn Replication" -Direction inbound -Protocol TCP -LocalPort $Cluster.endpointport -Action allow
		} else {
			Set-NetFirewallRule -DisplayName "SQL AlwaysOn Replication" -Direction inbound -Protocol TCP -LocalPort $Cluster.endpointport -Action allow
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
