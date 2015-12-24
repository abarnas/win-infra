########################################################################################################
# Script  : createDFSRGroup.ps1
# Usage   : creates and configures a DFS replication group
#
# Inputs  : UserAccount dictionary
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
# Create DFSR Group
function CreateDFSRGroup
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
		
		# See if the group already exists
		$group = Get-DfsReplicationGroup -GroupName $groupname
		if (-Not($group))
		{
			try
			{
				# Create the group and add the first two servers
				Write-Verbose "Creating DFSR group $groupname"
				New-DfsReplicationGroup -GroupName "$groupname" -DomainName $Domain.domainName | `
				New-DfsReplicatedFolder -FolderName "$replicationfolder" | `
				Add-DfsrMember -ComputerName "$primaryhub", "$secondaryhub"
				
				# Add the first and second members
				Write-Verbose "Adding primary members"
				Add-DfsrConnection -GroupName "$groupname" `
				-SourceComputerName "$primaryhub" -DestinationComputerName "$secondaryhub"
				
				# Set the first member to be the primary and define the data folder
				Set-DfsrMembership -GroupName "$groupname" `
				-FolderName "$replicationfolder" `
				-ContentPath "$contentpath" `
				-ComputerName "$primaryhub" `
				-PrimaryMember $True `
				-StagingPathQuotaInMB $stagingquota `
				-ConflictAndDeletedQuotaInMB $stagingquota `
				-Force
				
				# Set the second member
				Set-DfsrMembership -GroupName "$groupname" `
				-FolderName "$replicationfolder" `
				-ContentPath "$contentpath" `
				-ComputerName "$secondaryhub" `
				-StagingPathQuotaInMB $stagingquota `
				-ConflictAndDeletedQuotaInMB $stagingquota `
				-Force
				
				# Create the group schedule with bandwith throttling
				Set-DfsrGroupSchedule -GroupName "$groupname" `
				-Day Sunday,Monday,Tuesday,Wednesday,Thursday,Friday,Saturday `
				-BandwidthDetail 777777777777777777777777666666666666666666666666666666666666666666666666666666667777777777777777 `
				-UseUTC $True
				
				# Create a full bandwidth schedule between primary and secondaryhub
				Set-DfsrConnectionSchedule -GroupName "$groupname" `
				-SourceComputerName "$primaryhub" `
				-DestinationComputerName "$secondaryhub" `
				-ScheduleType Always `
				-UseUTC $True
			}
			catch
			{
				Throw "Error creating DFSR group $groupname because $($_.Exception.Message)"
			}
		}
		else
		{
			# Group already exists
			Write-Verbose "DFSR Group $groupname already exists. Skipping"
		}
	}
	
	# Get the credential object
	$credential = GetDomainCredential
	
	# Invoke the command
	$computerName = $env:COMPUTERNAME
	invoke-command -ComputerName $computerName `
				   -Credential $credential `
				   -Authentication CredSSP `
				   -ScriptBlock $scriptBlockContent `
				   -ArgumentList $Replication,$Domain
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
CreateDFSRGroup 