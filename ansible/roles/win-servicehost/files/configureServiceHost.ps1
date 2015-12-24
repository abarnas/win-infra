########################################################################################################
# Script  : ConfigureServiceHost.ps1
#
# Purpose : Prepares the service host 
# Author  : Ard-Jan Barnas
# Date    : 7/22/2015
# Inputs  : 
#
# Notes   : Configuration of FSW and SQL Backup target is controlled by the (SQL) cluster nodes to allow
#           the servicehost to support more than a single cluster and without having to pass cluster
#           details to the servicehost playbook. This allows better abstraction of service hosts.
########################################################################################################

# Parameters
[CmdletBinding()]
Param(
	[Parameter(Mandatory)]
	[psobject]$Domain=$null
)

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

# Main Functions


