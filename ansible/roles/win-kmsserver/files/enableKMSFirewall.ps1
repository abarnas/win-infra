#------------------------------------------------------------------------------------------------------------------
# Script  : enableFirewallSQL.ps1
#------------------------------------------------------------------------------------------------------------------

# Parameters
[CmdletBinding()]
Param(
	[Parameter(Mandatory)]
	[psobject]$Site=$null
)

#------------------------------------------------------------------------------------------------------------------
# Enable the KMS firewall ports
function enableFirewallKMS
{
	try
	{
		# Configure SQL endpoint replication port
		if (-Not(Get-NetFirewallRule -DisplayName "Key Management Service (TCP-In)" -ErrorAction SilentlyContinue)) {
			New-NetFirewallRule -DisplayName "Key Management Service (TCP-In)" -Direction inbound -Protocol TCP -LocalPort $Site.kms.port -Action allow
		} else {
			Set-NetFirewallRule -DisplayName "Key Management Service (TCP-In)" -Direction inbound -Protocol TCP -LocalPort $Site.kms.port -Action allow
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

# Make sure we have all the parameters that we need
if (-Not ($Site.kms.port)) { Throw "Error: missing win_site.kms.port parameter!" }

# Make sure we run as admin            
$usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()            
$IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                               
if (-not($IsAdmin))            
{            
	Write-Warning "Must run powerShell as Administrator to perform these actions"           
	return           
}

# Set firewall rules
enableFirewallKMS
