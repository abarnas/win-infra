########################################################################################################
# Script  : PrepareFileshareWitness.ps1
#
# Purpose : Prepares the FSW for failover clustering
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
# Configure Backup Share
function PrepareFileshareWitness
{
	# Compile the accesslist for the FSW share
	$accesslist = $Cluster.servicehost.fswaccesslist
	$accesslist += $Cluster.clustername + "$"
	
	# Compile the FSW share path and share name
	$fswfilepath = $Cluster.servicehost.fswrootdrive + "\" + $Cluster.clustername + "-" + $Cluster.servicehost.fswsharenamesuffix
	$fswsharename = $Cluster.clustername + "-" + $Cluster.servicehost.fswsharenamesuffix
	
	# Create the FileshareWitness target folder
	try
	{
		if (!(Test-Path $fswfilepath))
		{
			New-Item $fswfilepath -type Directory
		}
	}
	catch
	{
		Throw "Failed to create FileshareWitness folder $fswfilepath because $($_.Exception.Message)"
	}
	
	# Create the FSW share
	try
	{
		# See if the share already exists
		$smbShare = Get-SMBShare -Name $fswsharename -ErrorAction SilentlyContinue
		if (-Not($smbShare))
		{
			# Create share and set share permissions
			New-SMBShare `
			-Name $fswsharename `
			-Path $fswfilepath `
			-FullAccess $accesslist
			
		}
		else
		{
			# Share already exists. Update ACLs
			$shareaccess = Get-SmbShareAccess -Name "$fswsharename"
			foreach ($id in $accesslist)
			{
				if (-Not($shareaccess.Contains($id))) {
					Grant-SmbShareAccess -Name "$fswsharename" -AccountName "$id" -AccessRight Full -Force
				}
			}
		}

		# Set NTFS permissions
		$acl = Get-Acl $fswfilepath
		$acl.SetAccessRuleProtection($True, $False)
		
		foreach ($id in $accesslist)
		{
			$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($id,"FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
			$acl.AddAccessRule($rule)
		}
		
		Set-Acl $fswfilepath $acl
	}
	catch
	{
		Throw "Failed to create FileshareWitness share because $($_.Exception.Message)"
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
if (-Not ($Cluster.clustername)) { Throw "Error: missing CLuster.clustername parameter in Cluster dictionary!" }
if (-Not ($Cluster.servicehost.fswrootdrive)) { Throw "Error: missing filepath parameter in Cluster.servicehost dictionary!" }
if (-Not ($Cluster.servicehost.fswsharenamesuffix)) { Throw "Error: missing fswsharenamesuffix parameter in Cluster.servicehost dictionary!" }
if (-Not ($Cluster.servicehost.fswaccesslist)) { Throw "Error: missing accesslist parameter in Cluster.servicehost dictionary!" }

# Make sure we run as admin            
$usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()            
$IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                               
if (-not($IsAdmin))            
{            
	Write-Warning "Must run powerShell as Administrator to perform these actions"           
	return           
}

# Configure SQL Backup Share	
PrepareFileshareWitness




