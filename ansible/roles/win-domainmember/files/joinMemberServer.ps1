#------------------------------------------------------------------------------------------------------------------
# Script  : joinMemberServer.ps1
# Purpose : Joins a server to a forest or child domain
#
# Prereqs : Site-specific OU must have been created!
#
# Inputs  : Placement           - Specifies placement in the root forest or child domain
#           Topology		  	- Specifies forest/domain topology
#           Site        		- Default OU for member servers (hashtable)
#           DomainController	- Specify if adding a domain-cntroller-to-be. Omit for regular member servers
#			(see common.yml)
#------------------------------------------------------------------------------------------------------------------

# Parameters
[CmdletBinding()]
Param(
	[Parameter(Mandatory)]
	[string]$Placement=$null,

	[Parameter(Mandatory)]
	[psobject]$Topology=$null,

	[Parameter(Mandatory)]
	[psobject]$Site=$null
)

#----------------------------------------------------------------------------------------------
# Join server to the domain
function IsDomainMember
{
	try
	{
		$objWMI = Get-WMIObject -Class Win32_ComputerSystem -ComputerName $env:ComputerName
		if ($objWMI.Domain) 
		{
			if ($objWMI.Domain -eq "workgroup" -Or $objWMI -eq "WORKGROUp")
			{
				return $false
			}
			else
			{
				# System is domain member
				return $true
			}
		}
	}
	catch
	{
		Throw "Failed to check for domain membership because $($_.Exception.Message)"
	}
	
	# System is not a domain member
	return $false
}

#----------------------------------------------------------------------------------------------
# Join server to the domain
function JoinDomain
{
	try
	{
		# Build the OU path for this member server
		$sitename = $Site.sitename
		$serverDN = $Topology.organizationalunits.managedserversOU + "," + $Domain.rootDse
		$ouPath = "OU=$sitename,$serverDN"
		$Credential = GetDomainCredential
		
		Add-Computer -DomainName $Domain.domainName `
		-Credential $Credential `
		-OUPath $ouPath `
		-Force
	}
	catch
	{
		Throw "Failed to join domain because $($_.Exception.Message)"
	}		
}

#----------------------------------------------------------------------------------------------

function GetDomainCredential
{
	# Build the credentials object
	$domainUserName = $Domain.netbiosname + "\Administrator"
	$domainPassword = ConvertTo-SecureString $Domain.password -AsPlaintext -Force
	$DomainCredential = New-Object -typename System.Management.Automation.PSCredential -argumentlist $domainUserName, $domainPassword
	
	return $DomainCredential
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

# Make sure we have all the parameters that we need
if (-Not ($Placement)) { Throw "Error: missing Placement parameter!" }
if (-Not ($Site.sitename)) { Throw "Error: missing sitename parameter in Site!" }

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

if (-Not ($Domain.domainname)) { Throw "Error: missing domainName parameter in Topology!" }
if (-Not ($Domain.netbiosname)) { Throw "Error: missing domainNetBiosName parameter in Topology!" }
if (-Not ($Domain.password)) { Throw "Error: missing domainPassword parameter in Topology!" }
if (-Not ($Domain.rootDse)) { Throw "Error: missing rootDse parameter in Topology!" }
if (-Not ($Topology.organizationalunits.managedserversOU)) { Throw "Error: missing managedserversOU parameter in Topology!" }

# Make sure we run as admin            
$usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()            
$IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                               
if (-not($IsAdmin))            
{            
	Throw "Must run powerShell as Administrator to perform these actions"     
}

#Check if system is already on the domain. 
if (IsDomainMember)
{
	Write-Verbose "$env:COMPUTERNAME is already member of a domain. Skipping"
	exit 
}

# Install Active Directory Domain Services	
joinDomain
