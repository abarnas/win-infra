########################################################################################################
# Script  : renameDefaultFirstSite.ps1
#
# Purpose : Renames the Default-First-Site-name (used AFTER created a new forest)
# Author  : Ard-Jan Barnas
# Date    : 4/29/2015
# Inputs  : Topology		- Provides Enterprise Admin password
#         : SiteName        - New site name
#			(see common.yml)
#
########################################################################################################

# Parameters
[CmdletBinding()]
Param(
	[Parameter(Mandatory)]
	[psobject]$Topology=$null,
		
	[Parameter(Mandatory)]
	[psobject]$SiteName=$null
)

#----------------------------------------------------------------------------------------------
# Rename the site Default-First-Site-name
function RenameDefaultFirstSite
{
	try
	{
		$Credential = GetEnterpriseCredential
		Get-ADReplicationSite | Rename-ADObject -NewName $SiteName -Credential $Credential
	}
	catch
	{
		Write-Warning "Error renaming Default-First-Site-name because $($_.Exception.Message)"
		Exit 1
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

# Make sure we run as admin            
$usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()            
$IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                               
if (-not($IsAdmin))            
{            
	Throw "Must run powerShell as Administrator to perform these actions"     
}

# Make sure we have all the parameters that we need
if (-Not ($SiteName)) { Throw "missing default first site name!" }
if (-Not ($Topology.forest.password)) { Throw "Error: missing Password parameter in Topology!" }

# Run main functions
RenameDefaultFirstSite
