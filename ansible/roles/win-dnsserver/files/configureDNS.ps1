#------------------------------------------------------------------------------------------------------------
# Script  : /roles/win-dnsserver/configureDNS.ps1
# Purpose : Configure the DNS reverse lookup zones, conditional forwarder for KMS, and the DNS server
#           forwarders to the root forest.
#
# Inputs  : Topology		- AD forest/domain topology parameters
#           Site			- Site-specific information (sitename, location, DNS client settings, etc.)
#           CreateForwarder	- Specify when configuring child domain(s). Omit for forest DNS servers
#			(see common.yml)
#-------------------------------------------------------------------------------------------------------------

# Parameters
[CmdletBinding()]
Param(
	[Parameter(Mandatory)]
	[psobject]$Topology=$null,
		
	[Parameter(Mandatory)]
	[psobject]$Site=$null,
	
	[Parameter(Mandatory=$false)]
	[string]$Placement=$null
)

#----------------------------------------------------------------------------------------------
# Check if an object already exists in Active Directory
# You can use: CN=groupname,DC=....   or OU=ouname,DC=... 
Function ADObjectExists
{
	[CmdletBinding()]
	param(
		[string]$path
	)

	if ([ADSI]::Exists("LDAP://$path"))
	{
		return $true
	}
	
	return $false
}

#----------------------------------------------------------------------------------------------

# Create conditional forwarder for kms.cloud.cisco.com name resolution
function CreateConditionalForwarder
{
	# Build the array of forwarder addresses
	$MasterServers = @()
	$MasterServers += $Site.dns.primaryIDNS
	if ($Site.dns.secondaryIDNS)
	{
		$MasterServers += $Site.dns.secondaryIDNS
	}
	
	try
	{
			# Since there is no 'Get-DnsServerConditionalForwarderZone' try using Set. If it fails, the 
			# zone is not yet created. Otherwise the zone will simply be updated.
			Set-DnsServerConditionalForwarderZone `
			-Name $Site.kms.domainname `
			-MasterServers $MasterServers
	}
	catch
	{
		try
		{
			# Add the conditional forwarder (non AD integrated!!)
			Add-DnsServerConditionalForwarderZone `
			-Name $Site.kms.domainname `
			-MasterServers $MasterServers
		}
		catch
		{
			Throw "Error creating conditional forwarder because $($_.Exception.Message)"
		}
	}
}

#----------------------------------------------------------------------------------------------

# Crreate DNS server forwarder to root forest
function CreateDNSServerForwarder
{
	# Forwarders to the forest DNS servers are created for child domain controllers only
	
	if ($Placement -eq "domain")
	{
		Write-Host "Creating DNS Server forwarders"
		
		# Get the current list of forwarders from the primary DNS server in the current site
		try 
		{
			$forwarders = Get-DNSServerForwarder
		}
		catch
		{
			Throw "Error retrieving DNSServerForwarder in function CreateDNSServerForwarder because $($_.Exception.Message)"
		}
		
		# Determine if we already have the forwarders listed
		$primaryFound = $false
		$secondaryFound = $false
		foreach ($forwarder in $forwarders)
		{
			Write-Verbose "Looking for forwarder $forwarder"
			if ($forwarder.IPAddress -eq $Topology.forest.primaryDNS) {
				$primaryFound = $true
			}
			
			if ($forwarder.IPAddress -eq $Topology.forest.secondaryDNS) {
				$secondaryFound = $true
			}
		}
		
		# Add the DNS Server Forwarders
		try
		{
			# Add the primary 
			if (-Not($primaryFound)) {
				Write-Verbose "Adding primary DNS server forwarder"
				Add-DNSServerForwarder -IPAddress $Topology.forest.primaryDNS
			} else {
				Write-Verbose "DNS forwarder already exists"
			}
			

			# Add the secondary 
			if (-Not($secondaryFound)) {
				Write-Verbose "Adding secondary DNS server forwarder"
				Add-DNSServerForwarder -IPAddress $Topology.forest.secondaryDNS
			} else {
				Write-Verbose "DNS forwarder already exists"
			}
		}
		catch
		{
			Throw "Error creating DNSServerForwarder in function CreateDNSServerForwarder because $($_.Exception.Message)"
		}
	}
	else
	{
		Write-Host "Omitting DNS Server forwarders: not needed for forest domain controllers"
	}

}

#----------------------------------------------------------------------------------------------

# Crreate reverse lookup zone
function CreateReverseLookupZones
{
	$subnets = $Site.subnets.servicecloud
	foreach ($subnet in $subnets)
	{
		try
		{
			# Since there is no 'Get-DnsServerPrimaryZone' try using Set. If it fails, the 
			# zone is not yet created.
			Set-DnsServerPrimaryZone `
			-NetworkID $subnet `
			-ReplicationScope "Forest"
		}
		catch
		{
			try
			{
				Add-DnsServerPrimaryZone `
				-NetworkID $subnet `
				-ReplicationScope "Forest"
			}
			catch
			{
				Throw "Error creating reverse lookup zone for $subnet because $($_.Exception.Message)"
			}
		}
	}
}

#----------------------------------------------------------------------------------------------

function GetEnterpriseCredential
{
	# Build the credentials object
	$forestUserName = $Topology.forest.netbiosname + "\Administrator"
	$forestPassword = ConvertTo-SecureString $Topology.forest.password -AsPlaintext -Force
	$EnterpriseCredential = New-Object -typename System.Management.Automation.PSCredential `
	-argumentlist $forestUserName, $forestPassword
	
	return $EnterpriseCredential
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

# Make sure we have all the parameters that we need
if (-Not ($Placement)) { Throw "Error: missing domain Placement parameter in Topology!" }
if (-Not ($Topology.forest.primaryDNS)) { Throw "Error: missing primaryDNS parameter in Topology!" }
if (-Not ($Topology.forest.secondaryDNS)) { Throw "Error: missing secondaryDNS parameter in Topology!" }
if (-Not ($Topology.domain.primaryDNS)) { Throw "Error: missing primaryDNS parameter in Topology!" }
if (-Not ($Topology.domain.secondaryDNS)) { Throw "Error: missing secondaryDNS parameter in Topology!" }
if (-Not ($Site.subnets)) { Throw "Error: missing subnets parameter in Site!" }
if (-Not ($Site.subnets.servicecloud)) { Throw "Error: missing subnets.servicecloud parameter in Site!" }
#if (-Not ($Site.subnets.tenantcloud)) { Throw "Error: missing subnets.tenantcloud parameter in Site!" }
#if (-Not ($Site.subnets.internaldns)) { Throw "Error: missing subnets.internaldns parameter in Site!" }
if (-Not ($Site.dns.primaryIDNS)) { Throw "Error: missing primaryIDNS parameter in Site!" }
if (-Not ($Site.kms.domainname)) { Throw "Error: missing KMS domain name parameter in Site!" }

# Make sure we run as admin            
$usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()            
$IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                               
if (-not($IsAdmin))            
{            
	Throw "Must run powerShell as Administrator to perform these actions"     
}

# Run main functions
CreateDNSServerForwarder
CreateConditionalForwarder
CreateReverseLookupZones
