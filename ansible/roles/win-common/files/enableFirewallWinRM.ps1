#------------------------------------------------------------------------------------------------------------------
# Script  : enableFirewallWinRM.ps1
# Purpose : Makes sure WinRM is allowed on Domain and Private profiles
#------------------------------------------------------------------------------------------------------------------

function enableFirewallWinRM
{
	try
	{
		# Configure firewall to allow WinRM HTTPS connections.
		$fwtest1 = netsh advfirewall firewall show rule name="WinRM HTTPS"
		$fwtest2 = netsh advfirewall firewall show rule name="WinRM HTTPS" profile=any
		If ($fwtest1.count -lt 5)
		{
			Write-Verbose "Adding firewall rule to allow WinRM HTTPS."
			netsh advfirewall firewall add rule profile=any name="WinRM HTTPS" dir=in localport=5986 protocol=TCP action=allow
		}
		ElseIf (($fwtest1.count -ge 5) -and ($fwtest2.count -lt 5))
		{
			Write-Verbose "Updating firewall rule to allow WinRM HTTPS for any profile."
			netsh advfirewall firewall set rule name="WinRM HTTPS" new profile=any
		}
		Else
		{
			Write-Verbose "Firewall rule already exists to allow WinRM HTTPS."
		}
	}
	catch
	{
		Throw "Error creating firewall rule because $($_.Exception.Message)"
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

# Set the password
enableFirewallWinRM



