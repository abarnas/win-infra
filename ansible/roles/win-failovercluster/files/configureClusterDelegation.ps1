########################################################################################################
# Script  : configureClusterDelegation.ps1
# Usage   : configures delegation permission for the cluster computer account and OU creation ACLs
#
# Inputs  : 
########################################################################################################

# Parameters
[CmdletBinding()]
Param(
	[Parameter(Mandatory)]
	[string]$Placement=$null,

	[Parameter(Mandatory)]
	[psobject]$Cluster=$null,

	[Parameter(Mandatory)]
	[psobject]$Topology=$null
)

#----------------------------------------------------------------------------------------------
# Assign Create Child Object permissions to cluster computer account
function SetOUACLs
{
	$ADDrive = "AD:"
	$computer = $Cluster.clustername + "$"
	$ou = $Topology.organizationalunits.managedserversOU + "," + $Domain.rootDse
	
	# Load the required Module
	Import-Module -Name ActiveDirectory -ErrorAction SilentlyContinue | Out-Null
	try
	{
        # Test we have a connection to the AD drive
		Write-Verbose "Testing AD drive"
		Test-Path $ADDrive 

		$ActiveDirectoryRights = "ReadProperty,CreateChild,WriteProperty,GenericExecute"
		$AccessControlType = "Allow"
		$Inherit = "SelfAndChildren"
		$nullGUID = [guid]'00000000-0000-0000-0000-000000000000'
 		
		# Get the SSID of the computer object to add to the OU acl
		Write-Verbose "Getting SID of computer account $computer"
		$computerSID = Get-ADComputer -Identity $computer | Select-Object -ExpandProperty SID

		Write-Verbose "Retrieving OU $ou"
		# Get the OU
		$Container = Get-ADObject -Identity $ou
		$ContainerPath = $ADDrive + '\' + $Container.DistinguishedName

		# Get the current Acl
		$acl = Get-Acl -Path $ContainerPath
		
        # First Access Rule (ReadProperty, WriteProperty, GenericExecute)
        $ace = New-Object -TypeName System.DirectoryServices.ActiveDirectoryAccessRule `
		                  -ArgumentList $computerSID, $ActiveDirectoryRights, $AccessControlType, $Inherit, $nullGUID
        
		$acl.SetAccessRuleProtection($False, $True)

        # Add the new AccessRules to the current ACL
        $acl.AddAccessRule($ace)

		# Save the ACL / write-back to Ad
		Write-Verbose "Saving ACL"
		Set-Acl -Path $ContainerPath -AclObject $Acl
	}
	catch
	{
		Throw "Error setting OU permissions because $($_.Exception.Message)"
	}
}

#----------------------------------------------------------------------------------------------
# Allow delegation for the account
function AllowDelegation([string]$accountName)
{
	try
	{
		$computer = Get-ADComputer $accountName -Properties *
		$computer.TrustedForDelegation = $True
	}
	catch
	{
		$linenr = $_.InvocationInfo.ScriptLineNumber
		$line = $_.InvocationInfo.Line
		Throw "Error setting delegation permission to $accountName at line $linenr - $line. $($_.Exception.Message)"
	}
}

#----------------------------------------------------------------------------------------------

function GetDomainCredential
{
	# Build the credentials object
	$domainUserName = $Domain.netbiosname + "\Administrator"
	$domainPassword = ConvertTo-SecureString $Domain.password -AsPlaintext -Force
	$DomainCredential = New-Object -typename System.Management.Automation.PSCredential -argumentlist $domainUserName, $domainPassword
	
	Write-Verbose "Using domain credential $domainUserName"
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
if (-Not ($Cluster.clustername)) { Throw "Error: missing clustername!" }
if (-Not ($Domain.domainname)) { Throw "Error: missing domainName parameter in Domain!" }
if (-Not ($Domain.password)) { Throw "Error: missing domainPassword parameter in Domain!" }
if (-Not ($Domain.rootDse)) { Throw "Error: missing rootDse parameter in Domain!" }
if (-Not ($Topology.organizationalunits.managedserversOU)) { Throw "Error: missing organizationalunits.managedserversOU parameter in Topology!" }

# Make sure we run as admin            
$usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()            
$IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                               
if (-not($IsAdmin))            
{            
	Throw "Must run powerShell as Administrator to perform these actions"     
}

# Allow Delegation
$clusterAccountName = $Cluster.clustername
AllowDelegation $clusterAccountName

# Set Create Child object permissions for cluster account
SetOUACLs

