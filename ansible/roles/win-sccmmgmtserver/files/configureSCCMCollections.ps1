########################################################################################################
# Script  : ConfigureSCCMCollections.ps1
# Purpose : Create default device collection groups in SCCM for a site
#
# Inputs  : Topology		- AD Topology of Sites
#           DomainConfig	- Holds current site and subnet information
#			(see common.yml)
########################################################################################################

Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
Set-Location CIS:

# Parameters
[CmdletBinding()]
Param(
	[Parameter(Mandatory)]
	[psobject]$Topology=$null,
		
	[Parameter(Mandatory)]
	[psobject]$Site=$null,
)


#----------------------------------------------------------------------------------------------
# Check if an object already exists in Active Directory
# You can use: CN=groupname,DC=....   or OU=ouname,DC=... 
Function ADObjectExists
{
	[CmdletBinding()]
	param(
		[string]$path
	)

	if ([ADSI]::Exists("LDAP://$path"))
	{
		return $true
	}
	
	return $false
}

#----------------------------------------------------------------------------------------------

function CreateSiteBoundary
{
	# Try adding the Site-type boundary 
	$siteBoundaries = Get-CMBoundary | Where BoundaryType -eq 1
	if (-Not ($siteBoundaries.Value.Contains($sitename)))
	{
		$name = $Topology.forestNetbiosName + "/" + $Site.sitename
		New-CMBoundary -Name $name -Type ADSite -Value $sitename -Verbose 
	}

	# Try adding the Subnet-type boundary 
	$subnetBoundaries = Get-CMBoundary | Where BoundaryType -eq 1
	foreach ($subnet in $subnets)
	{
		if (-Not ($subnetBoundaries.Value.Contains($subnet)))
		{
			$name = $Topology.forestNetbiosName + "/" + $Site.sitename + "/" + $subnet
			#New-CMBoundary -Name $name -Type IPSubnet -Value $subnet -Verbose 
		}
	}
}

#----------------------------------------------------------------------------------------------

function CreateDeviceCollections
{
	$sitename = $Site.sitename
	
	# Create default collections hash table
    $deviceCollections = @{
        "Managed Servers $sitename" = @{queryName = "Query-Site-$sitename"; limitingCollection = "All Systems";query = "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ADSiteName = '" + $sitename + "'"};
        "Managed Servers $sitename - Group 01" = @{queryName = "Query-Site-$sitename-group01"; limitingCollection = "Managed Servers $sitename"; query = "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ADSiteName = '" + $sitename + "' and SMS_R_System.NetbiosName like '%01'"};
        "Managed Servers $sitename - Group 02" = @{queryName = "Query-Site-$sitename-group02"; limitingCollection = "Managed Servers $sitename"; query = "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ADSiteName = '" + $sitename + "' and SMS_R_System.NetbiosName like '%02'"};
        "Managed Servers $sitename - Group 03" = @{queryName = "Query-Site-$sitename-group03"; limitingCollection = "Managed Servers $sitename"; query = "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ADSiteName = '" + $sitename + "' and SMS_R_System.NetbiosName not like '%01' and SMS_R_System.NetbiosName not like '%02'"}
        }
		
	# sort hash table by name
    $deviceCollections = $deviceCollections.GetEnumerator() | Sort-Object Name

	# Create the collections if they don't already exist
    foreach ($col in $deviceCollections.Keys)
    {
        # Create the primary device collection for this site
        $collection = Get-CMDeviceCollection | Where Name -eq $col
        if (-Not ($collection))
        {
            # create the refresh schedule
            $Schedule = New-CMSchedule –RecurInterval Days –RecurCount 1

            # create the device collection
            New-CMDeviceCollection `
            -Name $col `
            -LimitingCollectionName $deviceCollections[$col].limitingCollection `
            -RefreshSchedule $Schedule `
            -RefreshType Periodic 

            # add query rule to collection
            Add-CMDeviceCollectionQueryMembershipRule `
            -CollectionName $col `
            -QueryExpression $deviceCollections[$col].query `
            -RuleName $deviceCollections[$col].queryName
        }
        else
        {
            Write-Host "Site collection $col already exists"
        }
    }
}

#----------------------------------------------------------------------------------------------

function GetEnterpriseCredential
{
	# Build the credentials object
	$forestUserName = $Topology.forest.netbiosname + "\Administrator"
	$forestPassword = ConvertTo-SecureString $Topology.forest.password -AsPlaintext -Force
	$EnterpriseCredential = New-Object -typename System.Management.Automation.PSCredential `
	-argumentlist $forestUserName, $forestPassword
	
	return $EnterpriseCredential
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

# Make sure we run as admin            
$usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()            
$IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                               
if (-not($IsAdmin))            
{            
	Throw "Must run powerShell as Administrator to perform these actions"     
}

# Make sure we have all the parameters that we need in DomainConfig
if (-Not ($Site.sitename)) { Throw "Error: missing SiteName parameter in SiteConfig!" }
if (-Not ($Site.subnets)) { Throw "Error: missing Subnets parameter in SiteConfig!" }
if (-Not ($Topology.forest.password)) { Throw "Error: missing Password parameter in Topology!" }
if (-Not ($Topology.forest.netbiosname)) { Throw "Error: missing forest.netbiosname parameter in Topology!" }

# Run main functions
CreateSiteBoundary
CreateDeviceCollections
	
