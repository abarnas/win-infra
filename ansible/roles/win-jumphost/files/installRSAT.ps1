########################################################################################################
# Script  : installRSAT.ps1
#
# Purpose : Install the RSAT tools
# Author  : Ard-Jan Barnas
# Date    : 7/22/2015
########################################################################################################

#----------------------------------------------------------------------------------------------
# Configure Quorum
function installRSAT
{
	try
	{
		# Install all the RSAT Features apart from RSAT-NIS, which is deprecated
		 
		#Get a list of features and order them by name
		$ListofFeatures = Get-WindowsFeature | Sort-Object -Property name
		 
		#Foreach feature , check if it starts with RSAT- and install it
		#IF it is RSAT-NIS , don't install it , as it is a deprecated feature
		 
		foreach ($RSATFeature in $ListofFeatures)
		{
			if ($RSATFeature.name -eq "RSAT-NIS")
			{
				write-host "Don't install " $RSATFeature.name
			}
			else
			{
				if ($RSATFeature.name -like "RSAT-*")
				{
					write-host "Installing "   $RSATFeature.name
					Add-WindowsFeature $RSATFeature.name
				}
				else
				{
				write-host   "Don't install " $RSATFeature.name
				}
			}
		}
		 
		#These ones are not prfixed with RSAT, but are part of the tools, so install them anyhow <img class="wp-smiley" style="height: 1em; max-height: 1em;" alt=":)" src="http://britv8.com/wp-includes/images/smilies/simple-smile.png">
		Add-WindowsFeature RDS-Licensing-UI
		Add-WindowsFeature WDS-AdminPack
		Add-WindowsFeature IPAM-Client-Feature
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

# Make sure we run as admin            
$usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()            
$IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                               
if (-not($IsAdmin))            
{            
	Write-Warning "Must run powerShell as Administrator to perform these actions"           
	return           
}

# Install RSAT	
installRSAT



