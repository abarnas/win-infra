########################################################################################################
# Script  : InstallFailoverCluster.ps1
#
# Purpose : Installs the Failover Cluster role
# Author  : Ard-Jan Barnas
# Date    : 7/22/2015
# Inputs  : 
#
########################################################################################################

#----------------------------------------------------------------------------------------------
# Install Failover Cluster role
function InstallFailoverCluster
{
	Install-WindowsFeature -Name Failover-Clustering -IncludeManagementTools
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
# none

# Make sure we run as admin            
$usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()            
$IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                               
if (-not($IsAdmin))            
{            
	Write-Warning "Must run powerShell as Administrator to perform these actions"           
	return           
}

# Install Volume Activation feature	
InstallFailoverCluster


