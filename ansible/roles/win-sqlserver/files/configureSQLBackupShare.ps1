########################################################################################################
# Script  : ConfigureSQLBackupShare.ps1
#
# Purpose : Prepares the service host for SQL Backups
# Author  : Ard-Jan Barnas
# Date    : 7/22/2015
# Inputs  : 
#
########################################################################################################

# Parameters
[CmdletBinding()]
Param(
	[Parameter(Mandatory)]
	[psobject]$SQLServer=$null
)

#----------------------------------------------------------------------------------------------
# Configure Backup Share
function ConfigureSQLBackupShare
{
	# Compile the accesslist for the backup share
	$accesslist = $SQLServer.servicehost.backupaccesslist
	$accesslist += $SQLServer.serviceaccount.username
	
	# Compile the backup target folder name
	$backupsharename = $SQLServer.servicehost.backupsharename
	$backupfilepath = $SQLServer.servicehost.backuprootdrive + "\" + $backupsharename
		
	# Create the SQL backup target folder
	try
	{
		if (!(Test-Path $backupfilepath)) {
			New-Item $backupfilepath -type Directory
		}
	}
	catch
	{
		Throw "Failed to create SQL backup folder $SQLbackupsharepath because $($_.Exception.Message)"
	}
	
	# Create the SQL backup share
	try
	{
		# See if the share already exists
		Write-Host "Creating SQL backup share $backupsharename"
		$smbShare = Get-SMBShare -Name $backupsharename -ErrorAction SilentlyContinue
		if (-Not($smbShare))
		{
			# Create share and set share permissions
			New-SMBShare `
			-Name $backupsharename `
			-Path $backupfilepath `
			-ReadAccess Everyone `
			-FullAccess $accesslist
		}
		else
		{
			# Share already exists. Update ACLs
			$shareaccess = Get-SmbShareAccess -Name "$backupsharename"
			foreach ($id in $accesslist)
			{
				Write-Host "Adding $id to share access list"
				if (-Not($shareaccess.Contains($id))) {
					Grant-SmbShareAccess -Name "$backupsharename" -AccountName "$id" -AccessRight Full -Force
				}
			}
		}
		
		# Update NTFS permissions
		$acl = Get-Acl $backupfilepath
		$acl.SetAccessRuleProtection($True, $False)
		foreach ($id in $accesslist)
		{
			Write-Host "Adding $id to NTFS permissions"
			$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($id,"FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
			$acl.AddAccessRule($rule)
		}
		
		Set-Acl $backupfilepath $acl
	}
	catch
	{
		$linenr = $_.InvocationInfo.ScriptLineNumber
		$line = $_.InvocationInfo.Line
		Throw "Failed to create share $SQLbackupshare at line $linenr - $line. $($_.Exception.Message)"
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
if (-Not ($SQLServer.serviceaccount.username)) { Throw "Error: missing serviceaccount.username parameter in SQLServer dictionary!" }
if (-Not ($SQLServer.servicehost.hostname)) { Throw "Error: missing hostname parameter in ServiceHost dictionary!" }
if (-Not ($SQLServer.servicehost.backuprootdrive)) { Throw "Error: missing backuprootdrive parameter in ServiceHost dictionary!" }
if (-Not ($SQLServer.servicehost.backupsharename)) { Throw "Error: missing backupsharename parameter in ServiceHost dictionary!" }
if (-Not ($SQLServer.servicehost.backupaccesslist)) { Throw "Error: missing backupaccesslist parameter in ServiceHost dictionary!" }


# Make sure we run as admin            
$usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()            
$IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                               
if (-not($IsAdmin))            
{            
	Write-Warning "Must run powerShell as Administrator to perform these actions"           
	return           
}

# Configure SQL Backup Share	
ConfigureSQLBackupShare
