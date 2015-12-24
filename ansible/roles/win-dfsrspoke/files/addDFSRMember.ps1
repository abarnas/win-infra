########################################################################################################
# Script  : addDFSRMember.ps1
# Usage   : Adds a new member to the DFSR group
########################################################################################################

# Parameters
[CmdletBinding()]
Param(
	[Parameter(Mandatory)]
	[psobject]$Placement=$null,

	[Parameter(Mandatory)]
	[psobject]$Replication=$null,

	[Parameter(Mandatory)]
	[psobject]$Topology=$null
)

#----------------------------------------------------------------------------------------------
# Add a node to the DFSR replication group
function AddDFSRMember
{
	$ScriptBlockContent = {
		param([psobject]$Replication,[psobject]$Domain)
		
		$groupname = $Replication.groupname
		$replicationfolder = $Replication.replicationfolder
		$primaryhub = $Replication.primaryhub.hostname
		$secondaryhub = $Replication.secondaryhub.hostname
		$stagingquota = $Replication.stagingquota
		$contentdrive = $Replication.contentdrive
		$contentfolder = $Replication.contentfolder
		$contentpath = Join-Path $contentdrive $contentfolder
		
		Write-Verbose "Getting replication group $groupname"
		$group = Get-DfsReplicationGroup -GroupName $groupname
		$group
		if ($group)
		{
			try
			{
				$computerName = $env:ComputerName
				
				# Add the current computer to the DFSR group
				Write-Verbose "Adding $computerName to DFSR group $groupname"
				Add-DfsrMember -GroupName "$groupname" -DomainName $Domain.domainName -ComputerName $ComputerName
				
				# Create the connection
				Write-Verbose "Creating connection $primaryhub-$ComputerName"
				Add-DfsrConnection -GroupName "$groupname" `
				-SourceComputerName "$primaryhub" -DestinationComputerName "$ComputerName"

				Write-Verbose "Creating connection $secondaryhub-$ComputerName"
				Add-DfsrConnection -GroupName "$groupname" `
				-SourceComputerName "$secondaryhub" -DestinationComputerName "$ComputerName"
			
				# Set the membership details
				Write-Verbose "Setting DFSR membership details for $ComputerName"
				Set-DfsrMembership -GroupName "$groupname" `
				-FolderName "$replicationfolder" `
				-ContentPath "$contentpath" `
				-ComputerName "$ComputerName" `
				-StagingPathQuotaInMB $stagingquota `
				-ConflictAndDeletedQuotaInMB $stagingquota `
				-Force
			}
			catch
			{
				$linenr = $_.InvocationInfo.ScriptLineNumber
				$line = $_.InvocationInfo.Line
				Throw "Error at line $linenr - $line $($_.Exception.Message)"
			}
		}
		else
		{
			# DFSR group not found
			Throw "DFSR Group $groupname not found!"
		}
	}
	
	# Get the credential object
	$credential = GetDomainCredential
	
	# Invoke the command
	invoke-command -ComputerName $env:COMPUTERNAME `
				   -Credential $credential `
				   -Authentication CredSSP `
				   -ScriptBlock $scriptBlockContent `
				   -ArgumentList $Replication,$Domain
}

#----------------------------------------------------------------------------------------------
# Check prerequisites
function CheckPrequisites
{
	# See if the host is already member of the DFSR group
	try
	{
		Write-Verbose "Checking if $ComputerName is already a member"	
		$member = Get-DfsrMember -GroupName "$groupname" -DomainName $Domain.domainName -ComputerName $ComputerName
	}
	catch {
		$member = $null
	}

	if ($member) {
		return $False
	}
	
	# Check the connection drive
	$contentdrive = $Replication.contentdrive
	if (-Not(Test-Path $contentdrive))
	{
		Throw "Error: DFSR content drive $contentdrive does not exist!"
	}
	
	return $True
}

#----------------------------------------------------------------------------------------------

function GetDomainCredential
{
	# Build the credentials object
	$domainUserName = $Domain.netbiosname + "\Administrator"
	$domainPassword = ConvertTo-SecureString $Domain.password -AsPlaintext -Force
	$DomainCredential = New-Object -typename System.Management.Automation.PSCredential -argumentlist $domainUserName, $domainPassword
	
	return $DomainCredential
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
if ($Placement -eq "forest") {
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
	Throw "Error: Placement misconfigured. Needs to specify domain or forest. Current value: $Placement"
}

# Make sure we have all the parameters that we need
if (-Not ($Replication.groupname)) { Throw "Error: missing groupname in Replication dictionary!" }
if (-Not ($Replication.replicationfolder)) { Throw "Error: missing replicationfolder in Replication dictionary!" }
if (-Not ($Replication.contentdrive)) { Throw "Error: missing contentdrive in Replication dictionary!" }
if (-Not ($Replication.contentfolder)) { Throw "Error: missing contentfolder in Replication dictionary!" }
if (-Not ($Domain.domainname)) { Throw "Error: missing domainName parameter in Domain!" }
if (-Not ($Domain.password)) { Throw "Error: missing domainPassword parameter in Domain!" }

# Make sure we run as admin            
$usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()            
$IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                               
if (-not($IsAdmin))            
{            
	Throw "Must run powerShell as Administrator to perform these actions"     
}

# Add to group
AddDFSRMember
 