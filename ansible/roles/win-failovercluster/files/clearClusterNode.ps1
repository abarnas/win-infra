########################################################################################################
# Script  : ClearClusterNode.ps1
#
# Purpose : Clears the nodes in a cluster from a previous attempt to configure a cluster
# Author  : Ard-Jan Barnas
# Date    : 7/22/2015
# Inputs  : 
#
########################################################################################################

#----------------------------------------------------------------------------------------------
# Create the failover cluster
function ClearClusterNode
{
	Clear-ClusterNode -Force
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
	return           
}

# Import module
Import-Module FailoverClusters

# Configure Volume Activation feature	
ClearClusterNode


