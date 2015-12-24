########################################################################################################
# Script  : RemoveDefaultIPSiteLink.ps1
# Purpose : Configure the first default IP link
# Inputs  : Topology - AD Topology of Sites
########################################################################################################

# Parameters
[CmdletBinding()]
Param(
	[Parameter(Mandatory)]
	[psobject]$Topology=$null
)


#Cleanup default IP site link# First remove the default sitelink
function RemoveDefaultIPSiteLink
{
	$Credential = GetEnterpriseCredential
	
	try
	{
		Remove-ADReplicationSiteLink `
		-Identity "DEFAULTIPSITELINK" `
		-Confirm:$False `
		-Credential $Credential
	}
	catch
	{
		# do nothing - site link not found
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

# Make sure we have all the parameters that we need in DomainConfig
if (-Not ($Topology.forest.password)) { Throw "Error: missing Password parameter in Topology!" }

# Make sure we run as admin            
$usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()            
$IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                               
if (-not($IsAdmin))            
{            
	Throw "Must run powerShell as Administrator to perform these actions"     
}

# Run main functions
RemoveDefaultIPSiteLink
	
