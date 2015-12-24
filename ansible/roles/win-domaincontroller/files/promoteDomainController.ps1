# ------------------------------------------------------------------------------------------------------------------
# Script  : promoteDomainController.ps1
# Purpose : Add a domain controller to an exisiting forest or domain
#
# Inputs  : Topology	- Specifies forestName, administrator password, domain mode
#           Site		- Specifies sitename, domainName, administrator password, domain mode
#           Placement   - Specifies to add a DC to the root forest or a child domain
#			(see common.yml)
# ------------------------------------------------------------------------------------------------------------------

# Parameters
[CmdletBinding()]
Param(
	[Parameter(Mandatory)]
	[psobject]$Topology=$null,

	[Parameter(Mandatory)]
	[psobject]$Site=$null,

	[Parameter(Mandatory)]
	[string]$Placement=$null
)

#----------------------------------------------------------------------------------------------
# Install and configure ADDS
Function PromoteDomainController
{
	try
	{
		# Let's see if the server is already promoted
		Write-Verbose "Checking if server is promoted"
		(Get-ADDomain).DomainMode
	}
	catch
	{
		# Server is not promoted. Let's do it...
		$domainName = $Domain.domainName
		$siteName = $Site.sitename
		Write-Verbose "Adding domain controller in site $siteName to $domainName"

		# Build the credentials object
		$username = $Domain.netbiosname + "\Administrator"
		$password = ConvertTo-SecureString $Domain.password -AsPlaintext -Force
		$credential = New-Object -typename System.Management.Automation.PSCredential -argumentlist $username, $password
		
		try
		{
			Import-Module ADDSDeployment
			Install-ADDSDomainController -CreateDnsDelegation:$false `
			-Credential $credential `
			-DatabasePath 'C:\Windows\NTDS' `
			-DomainName $domainName `
			-InstallDns:$true `
			-SiteName $siteName `
			-LogPath 'C:\Windows\NTDS' `
			-NoGlobalCatalog:$false `
			-SafeModeAdministratorPassword $password `
			-SysvolPath 'C:\Windows\SYSVOL' `
			-NoRebootOnCompletion:$true `
			-Force:$true
		}
		catch
		{
			Throw "Failed to add domain controller because $($_.Exception.Message)"
		}		
	}
}

#----------------------------------------------------------------------------------------------
# Setup error handling
$VerbosePreference = "Continue"

# Setup error handling.
Trap
{
    Write-Error $_
    Exit 1
}
$ErrorActionPreference = "Stop"

#----------------------------------------------------------------------------------------------
# MAIN
#----------------------------------------------------------------------------------------------

# Make sure we run as admin            
$usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()            
$IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                               
if (-not($IsAdmin))            
{            
	Write-Warning "Must run powerShell as Administrator to perform these actions"     
	exit 1
}

# Check that we have all the necessary domain parameters
if (-Not ($Placement)) { Throw "Error: missing Placement parameter!" }
if (-Not ($Site.sitename)) { Throw "Error: missing SiteName parameter in SiteConfig!" }

# Set the domain dictionary to use
if ($Placement -eq "forest") {
	Write-Verbose "Active Directory placement set to Forest"
	$Domain = $Topology.forest
}
elseif ($Placement -eq "domain")
{
	Write-Verbose "Active Directory placement set to Domain"
	$Domain = $Topology.domain
}
else 
{
	Throw "Error: Placement misconfigured. Needs to specify domain or forest. Current value: $Placement"
}


if (-Not ($Domain.netBiosName)) { Throw "Error: missing NetBiosName parameter in Topology!" }
if (-Not ($Domain.password)) { Throw "Error: missing Password parameter in Topology!" }
if (-Not ($Domain.domainMode)) { Throw "Error: missing domainMode parameter in Topology!" }

# Install Active Directory Domain Services	
PromoteDomainController
