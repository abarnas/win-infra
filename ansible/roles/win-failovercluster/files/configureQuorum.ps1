########################################################################################################
# Script  : ConfigureQuorum.ps1
#
# Purpose : Configures the failover cluster's quorum
# Author  : Ard-Jan Barnas
# Date    : 7/22/2015
# Inputs  : Cluster
#
########################################################################################################

# Parameters
[CmdletBinding()]
Param(
	[Parameter(Mandatory)]
	[psobject]$Cluster=$null
)

#----------------------------------------------------------------------------------------------
# Configure Quorum
function ConfigureQuorum
{
	$quorumShare = "\\" + $Cluster.servicehost.hostname + "\" + $Cluster.clustername + "-" + $Cluster.servicehost.fswsharenamesuffix
	
	try
	{
		$quorum = Get-ClusterQuorum $Cluster.clustername
		if ($quorum.QuorumResource)
		{
			Write-Verbose "Quorum already configured: "
			$quorum.QuorumResource
		}
		else
		{
			Set-ClusterQuorum -NodeAndFileShareMajority $quorumShare
		}
	}
	catch
	{
		Throw "Failed to configure the cluster quorum because $($_.Exception.Message)"
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

# Make sure we have the required parameters
if (-Not ($Cluster.clustername)) { Throw "Error: missing clustername parameter in Cluster dictionary!" }
if (-Not ($Cluster.servicehost.hostname)) { Throw "Error: missing hostname parameter in Cluster.servicehost dictionary!" }
if (-Not ($Cluster.servicehost.fswsharenamesuffix)) { Throw "Error: missing fswsharenamesuffix parameter in Cluster.servicehost dictionary!" }

# Make sure we run as admin            
$usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()            
$IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                               
if (-not($IsAdmin))            
{            
	Write-Warning "Must run powerShell as Administrator to perform these actions"           
	return           
}

# Configure Cluster Quorum	
ConfigureQuorum



