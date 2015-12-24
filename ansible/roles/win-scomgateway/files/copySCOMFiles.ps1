#------------------------------------------------------------------------------------------------------------
# Script  : /roles/win-sqlserver/installSQLServer.ps1
# Purpose : Install SQL server
#
# Inputs  : Cluster, Domain
#-------------------------------------------------------------------------------------------------------------

# Parameters
[CmdletBinding()]
Param(
	[Parameter(Mandatory)]
	[string]$Placement=$null,

	[Parameter(Mandatory)]
	[psobject]$SCOM=$null,

	[Parameter(Mandatory=$false)]
	[psobject]$Topology=$null,

	[Parameter(Mandatory=$false)]
	[psobject]$Repository=$null
)

#----------------------------------------------------------------------------------------------

function TestTargetFolder($targetFolder)
{
	if (!(Test-Path $targetFolder))
	{
		Write-Host "Creating folder $targetFolder"
		New-Item $targetFolder -type Directory
	}
}

#----------------------------------------------------------------------------------------------

function CopyGatewayInstaller
{
	# Map network drive using domain credentials
	$credential = GetDomainCredential
	$sourcefolder = "\\" + $Repository.source
	$sourcefolder = Join-Path $sourcefolder	$Repository.scomgatewaysourcefolder
	
	$logpath = $Repository.logpath
	$gwpath = Join-Path $logpath "SCOM"

	# Create the support folder for log results
	TestTargetFolder $logpath
	TestTargetFolder $gwpath
	
	try
	{
		# Map drive
		Write-Host "Mapping drive X: to $sourcefolder"
		$unc = New-PSDrive -Name X -PSProvider FileSystem -Credential $credential -Root $sourcefolder
		${source} = $unc.Name + ":\*.*" 
		${dest} = $Repository.logpath + "\SCOM"

		# Copy the GatewayApprovalTool files to the install directory
		Write-Host "Copying ${source} to ${dest}"
		Copy-Item "${source}" -Destination "${dest}" -Force -Recurse

		# Unmap drive X
		Write-Host "Unmapping drive X:"
		Remove-PSDrive X
	}
	catch
	{
		$linenr = $_.InvocationInfo.ScriptLineNumber
		$line = $_.InvocationInfo.Line
		Throw "Error copying SCOM Gateway installer at line $linenr - $line. $($_.Exception.Message)"
	}
}

#----------------------------------------------------------------------------------------------

function CopyMOMCertImport
{
	# Map network drive using domain credentials
	$credential = GetDomainCredential
	$sourcefolder = "\\" + $Repository.source
	$sourcefolder = Join-Path $sourcefolder	$Repository.scomsupporttoolsfolder
	
	try
	{
		# Map Drive
		Write-Host "Mapping drive X: to $sourcefolder"
		$unc = New-PSDrive -Name X -PSProvider FileSystem -Credential $credential -Root $sourcefolder
		${source} = $unc.Name + ":\" + $Repository.scomcertimporttool
		${dest} = $Repository.logpath + "\SCOM"
		
		# Copy the GatewayApprovalTool files to the install directory
		Write-Host "Copying ${source} to ${dest}"
		Copy-Item "${source}" -Destination "${dest}" -Force

		# Unmap drive X
		Write-Host "Unmapping drive X:"
		Remove-PSDrive X
	}
	catch
	{
		$linenr = $_.InvocationInfo.ScriptLineNumber
		$line = $_.InvocationInfo.Line
		Throw "Error copying SCOM Gateway installer at line $linenr - $line. $($_.Exception.Message)"
	}
}

#----------------------------------------------------------------------------------------------

function GetDomainCredential
{
	# Build the credentials object
	$userName = $Domain.netbiosname + "\Administrator"
	$password = ConvertTo-SecureString $Domain.password -AsPlaintext -Force
	$Credential = New-Object -typename System.Management.Automation.PSCredential -argumentlist $userName, $password
	Write-Host "Using user account $userName"
	
	return $Credential
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

# Set the domain dictionary to use
if ($Placement -eq "forest") 
{
	Write-Verbose "Active Directory placement set to Forest"
	$Domain = $Topology.forest
}
elseif ($Placement -eq "domain")
{
	Write-Verbose "Active Directory placement set to Domain"
	$Domain = $Topology.domain
}
else
{
	Throw "Invalid domain placement specified. Must be domain or forest!"
}

# Make sure we have all the parameters that we need
if (-Not ($Domain.netbiosname)) { Throw "Error: missing netbiosname parameter in Domain!" }
if (-Not ($Repository.source)) { Throw "Error: missing Source parameter in Repository!" }
if (-Not ($Repository.logpath)) { Throw "Error: missing logpath parameter in Repository!" }
if (-Not ($Repository.scomgatewaysourcefolder)) { Throw "Error: missing scomgatewaysourcefolder parameter in Repository!" }
if (-Not ($Repository.scomgatewaysourcefile)) { Throw "Error: missing scomgatewaysourcefile parameter in Repository!" }
if (-Not ($Repository.scomsupporttoolsfolder)) { Throw "Error: missing scomsupporttoolsfolder parameter in Repository!" }
if (-Not ($Repository.scomcertimporttool)) { Throw "Error: missing scomcertimporttool parameter in Repository!" }
if (-Not ($Repository.logpath)) { Throw "Error: missing logpath parameter in Repository!" }

# Make sure we run as admin            
$usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()            
$IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                               
if (-not($IsAdmin))            
{            
	Throw "Must run powerShell as Administrator to perform these actions"     
}

#Install SQL Server
CopyGatewayInstaller
CopyMOMCertImport



