########################################################################################################
# Script  : ConfigureFailoverCluster.ps1
#
# Purpose : Installs the Failover Cluster role
# Author  : Ard-Jan Barnas
# Date    : 7/22/2015
# Inputs  : Cluster, Domain
#
########################################################################################################

# Parameters
[CmdletBinding()]
Param(
	[Parameter(Mandatory)]
	[psobject]$Placement=$null,
	
	[Parameter(Mandatory)]
	[psobject]$Cluster=$null,
	
	[Parameter(Mandatory)]
	[psobject]$Topology=$null
)

#----------------------------------------------------------------------------------------------
# Create the failover cluster
function ConfigureFailoverCluster
{
	# Check if the cluster already exists
	try
	{
		$cluster = Get-Cluster $Cluster.clustername
		if ($cluster) 
		{
			Write-Verbose "Cluster already exists. Skipping"
		}
	}
	catch
	{	
		try
		{
			$clusterName = $Cluster.clustername
			$clustervip = $Cluster.clustervip
			$nodes = @($Cluster.clusternodes)
			$computerName = $env:ComputerName

			$domainCredential = GetDomainCredential
			$clusterSession = New-PSSession -ComputerName $computerName -Credential $domainCredential -Authentication Credssp

			$scriptBlockContent = {
				param($clsname, $clsnodes, $clsvip)
				Write-Host "Creating failover cluster $clsname with vip $clsvip"
				New-Cluster -Name $clsname -Node $clsnodes -StaticAddress $clsvip -NoStorage
			}
			
			Invoke-Command -Session $clusterSession -ScriptBlock $ScriptBlockContent -ArgumentList $clusterName, $nodes, $clustervip
		}
		catch
		{
			$linenr = $_.InvocationInfo.ScriptLineNumber
			$line = $_.InvocationInfo.Line
			Throw "Error creating cluster at line $linenr - $line. $($_.Exception.Message)"
		}
	}
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

# Make sure we have the required parameters
if (-Not ($Cluster.clustername)) { Throw "Error: missing clustername parameter in Cluster dictionary!" }
if (-Not ($Cluster.clustervip)) { Throw "Error: missing clustervip parameter in Cluster dictionary!" }
if (-Not ($Cluster.controlnode)) { Throw "Error: missing controlNode parameter in Cluster dictionary!" }
if (-Not ($Cluster.clusternodes)) { Throw "Error: missing Nodes parameter in Cluster dictionary!" }
if (-Not ($Domain.domainname)) { Throw "Error: missing domainName parameter in Topology!" }
if (-Not ($Domain.netbiosname)) { Throw "Error: missing domainNetBiosName parameter in Topology!" }
if (-Not ($Domain.password)) { Throw "Error: missing domainPassword parameter in Topology!" }

# Make sure we run as admin            
$usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()            
$IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                               
if (-not($IsAdmin))            
{            
	Write-Warning "Must run powerShell as Administrator to perform these actions"           
	return           
}

# Import module
Import-Module FailoverClusters

# Configure Volume Activation feature	
ConfigureFailoverCluster
