########################################################################################################
# Script  : setLocalAdminPassword.ps1
#
# Purpose : Sets the site-specific local administrator password 

# Inputs  : Site - Site specific parameters
#			(see common.yml)
########################################################################################################

# Parameters
[CmdletBinding()]
Param(
	[Parameter(Mandatory)]
	[string]$Password=$null
	)
	
#----------------------------------------------------------------------------------------------

function SetAdminPassword
{
	try
	{
		$computerName = gc env:computerName
		$user = [ADSI]"WinNT://$computerName/Administrator,User"
		$user.SetPassword($Password)
		$user.SetInfo()
	}
	catch
	{
		Throw "Error changing local admin password $Password because $($_.Exception.Message)"
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

# Make sure we have all the parameters that we need
if (-Not ($Password)) { Throw "Error: missing password parameter!" }

# Make sure we run as admin            
$usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()            
$IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                               
if (-not($IsAdmin))            
{            
	Write-Warning "Must run powerShell as Administrator to perform these actions"           
	return           
}

# Set the password
SetAdminPassword



