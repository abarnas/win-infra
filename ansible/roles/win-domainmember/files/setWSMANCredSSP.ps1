########################################################################################################
# Script  : setWSMANCredSPP.ps1
#
# Purpose : Configures policies and SPNs for second-hop credential authentication
# Author  : Ard-Jan Barnas
# Date    : 7/22/2015
# Inputs  : Disable/Enable, Cluster, Domain
#
########################################################################################################

# Parameters
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$false)]
	[switch]$Enable,
	
	[Parameter(Mandatory=$false)]
	[switch]$Disable,
	
	[Parameter(Mandatory=$false)]
	[psobject]$Delegates=$null,
	
	[Parameter(Mandatory=$false)]
	[psobject]$Domain=$null
)

#----------------------------------------------------------------------------------------------
# Configure local computer policy on the servicehost for CredSSP connections, adding SPNs
function Test-RegistryValue 
{
	# Needs implementing in the future. For now, return False
	return $false
}

#----------------------------------------------------------------------------------------------
# Build the array of delegates
function GetDelegates
{
	$arrDelegates = @()
	if ($Delegates) {
		$arrDelegates = @($Delegates)
	}
	
	if ($Domain)
	{
		if (-Not($Domain.domainName)) {
			Throw "Error: missing domainName parameter in Domain!"
		}
		
		# Add the current domain name
		$arrDelegates += "*." + $Domain.domainName
	}
	else
	{
		# Add the local computer account if we're not a domain member
		$arrDelegates += $env:COMPUTERNAME
	}
	
	return $arrDelegates
}

#----------------------------------------------------------------------------------------------
# Main Update WSMAN Policy function
function UpdateWSMANPolicy([psobject]$arrDelegates)
{
	Write-Host "Adding WSMAN polcies to AllowFreshCredentials registry key"
	
	# Registry keys used by CredSSP
	$strRegKey = 'AllowFreshCredentialsWhenNTLMOnly'
	$strParentRegKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation'
	
	try
	{
		# Check registry for the CredentialsDelegation key
		if (!(Test-Path $strParentRegKey)) {
			md $strParentRegKey
		}
		
		# Check registry for the allowed entries
		$key = Join-Path $strParentRegKey $strRegKey
		Write-Host "Using registry key $key"
		
		if (!(Test-Path $key))
		{
			md $key
		}

		$strChildItems = Get-item -path $key
		$i = $strChildItems.ValueCount + 1
		
		#################
		New-ItemProperty -Path $key -Name $i -Value "WSMAN/*" -PropertyType String -Force | Out-Null
		return
		##################
		
		$strChildItems = Get-item -path $key
		$i = $strChildItems.ValueCount + 1

		foreach ($d in $arrDelegates)
		{
			$delegate = "WSMAN/" + $d
			$result = Test-RegistryValue -Path $key -Value $delegate
			if (!($result))
			{
				New-ItemProperty -Path $key -Name $i -Value $delegate -PropertyType String -Force | Out-Null
				$i++
			}
		}
	}
	catch
	{
		Throw "Failed to enable WSMAN CredSSP registry entries because $($_.Exception.Message)"
	}
}

#----------------------------------------------------------------------------------------------
# Enable CredSSP
function EnableCredSSP([psobject]$arrDelegates)
{
	try
	{
		# Enable the server role
		Write-Host "Enabling WSMANCredSSP Server role"
		Enable-WSMANCredSSP -Role Server -Force
		
		# Enable the client role 
		Write-Host "Enabling WSMANCredSSP Client role"
#		Enable-WSMANCredSSP -Role Client -DelegateComputer $arrDelegates -Force
		Enable-WSMANCredSSP -Role Client -DelegateComputer "*" -Force
	}
	catch
	{
		Throw "Failed to enable WSMAN CredSSP because $($_.Exception.Message)"
	}
}

#----------------------------------------------------------------------------------------------
# Disable WSMANCredSSP
function DisableWSMANCredSSP
{
	try
	{
		# Disable the server role
		Write-Host "Disabling WSMANCredSSP Server role"
		Disable-WSMANCredSSP -Role Server 
		
		# Enable the client role 
		Write-Host "Disabling WSMANCredSSP Client role"
		Disable-WSMANCredSSP -Role Client
	}
	catch
	{
		Throw "Failed to disable WSMAN CredSSP because $($_.Exception.Message)"
	}
}

#----------------------------------------------------------------------------------------------
# Setup error handling
$VerbosePreference = "Continue"

# Setup error handling.
Trap
{
	$strErr = "ERROR at line " + $_.InvocationInfo.ScriptLineNumber + ": " + $_.InvocationInfo.Line + " " + $_
	Write-Host $strErr
    Exit 1
}
$ErrorActionPreference = "Stop"

#----------------------------------------------------------------------------------------------
# MAIN
#----------------------------------------------------------------------------------------------

# Make sure we have the required parameters
# N/a

# Make sure we run as admin            
$usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()            
$IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                               
if (-not($IsAdmin))            
{            
	Write-Warning "Must run powerShell as Administrator to perform these actions"           
	return           
}

# Enable
if ($Enable)
{
	# Create the delegates array
	$arrDelegates = GetDelegates

	write-host $arrDelegates
	
	# Update WSMAN policy and SPNs
	EnableCredSSP($arrDelegates)
	UpdateWSMANPolicy($arrDelegates)
}

# Disable
if ($Disable)
{
	DisableWSMANCredSSP
}




