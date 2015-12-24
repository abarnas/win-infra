########################################################################################################
# Script  : InstallKMS.ps1
#
# Purpose : Installs the KMS service and activates 
# Author  : Ard-Jan Barnas
# Date    : 5/10/2015
# Inputs  : win_site
########################################################################################################

# Parameters
[CmdletBinding()]
Param(
	[Parameter(Mandatory)]
	[psobject]$Site=$null
	)
	

# Delete the default registry keys for KMS Service Name and Port, forcing activation with MSFT
function RemoveKMSRegistryKey
{
	$ErrorActionPreference = "SilentlyContinue"
	if (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform" -Name KeyManagementServicePort)
	{
		$ErrorActionPreference = "Stop"
		try
		{
			Remove-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform" -Name KeyManagementServicePort
		}
		catch
		{
			Throw "Error removing registry key HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform because $($_.Exception.Message)"
		}
	}

	$ErrorActionPreference = "SilentlyContinue"
	if (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform" -Name KeyManagementServiceName)
	{
		$ErrorActionPreference = "Stop"
		try
		{
			Remove-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform" -Name KeyManagementServiceName
		}
		catch
		{
			Throw "Error removing registry key HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform because $($_.Exception.Message)"
		}
	}
	
	$ErrorActionPreference = "Stop"
}


Function SetVolumeLicenseKey
{
	# Define some registry constants            
	$HKLM = 2147483650
	$Key1 = 'SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform'
	$Key2 = 'SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform'
	$ProductKey = $Site.kms.hostkey
	
	$TargetComputer = gc env:computername
	
	# Prepare a default HT            
	$wmiHT = @{            
		ErrorAction = "Stop";            
	}   
	
	# Get the SPP service version on the remote machine
	try
	{
		$SLsvc = Get-WmiObject -Query 'Select Version from SoftwareLicensingService' @wmiHT
		$Version = $SLsvc.Version
	} 
	catch 
	{
		Throw "Failed to query WMI on $TargetComputer because $($_.Exception.Message)"
	}
	
	# Make sure the remote computer is W8/2012 as it seems that: 
	# 'The Windows 8 version of SLMgr.vbs does not support remote connections to Vista/WS08 and Windows 7/WS08R2 machines'
	if (-not([version]$Version -gt ([version]'6.2')))            
	{   Throw "This computer does not support this version of SLMgr.vbs"
	}
	
	# Here we go!
	try
	{
		Write-Verbose -Message "Installing product key $ProductKey on $TargetComputer"
		Invoke-WmiMethod -InputObject $SLsvc -Name InstallProductKey -ArgumentList $ProductKey @wmiHT | Out-Null
		Invoke-WmiMethod -InputObject $SLsvc -Name RefreshLicenseStatus @wmiHT | Out-Null
		$SLProduct = Get-WmiObject -Query 'Select * FROM SoftwareLicensingProduct WHERE PartialProductKey <> null' @wmiHT
		Invoke-WmiMethod -Path "ROOT\DEFAULT:StdRegProv" -Name SetStringValue -ArgumentList $HKLM,$Key1,$Version,"KeyManagementServiceVersion" @wmiHT | Out-Null
		Invoke-WmiMethod -Path "ROOT\DEFAULT:StdRegProv" -Name SetStringValue -ArgumentList $HKLM,$Key2,$Version,"KeyManagementServiceVersion" @wmiHT | Out-Null
		'Installed product key {0} successfully on {1}.' -f $ProductKey,$TargetComputer

		# ' Avoid using a MAK activation count up unless needed'
		'Activating {0} ({1}) ...' -f ($SLProduct.Name),($SLProduct.ID)
		if (($SLProduct.Description -notmatch "MAK") -or ($SLProduct.LicenseStatus -ne 1))
		{
			Write-Verbose -Message "Attempting to activate product on $TargetComputer"
			Invoke-WmiMethod -InputObject $SLProduct -Name Activate @wmiHT | Out-Null
			Invoke-WmiMethod -InputObject $SLSvc -Name RefreshLicenseStatus @wmiHT | Out-Null
		}
		'Product activated successfully on {0}.' -f $TargetComputer
	} 
	catch
	{
		Throw "Failed to install key and activate computer $TargetComputer because $($_.Exception.Message)"
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
if (-Not ($Site.kms.hostkey)) { Throw "Error: missing parameter Site.kms.hostkey" }

# Make sure we run as admin            
$usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()            
$IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                               
if (-not($IsAdmin))            
{            
	Write-Warning "Must run powerShell as Administrator to perform these actions"           
	return           
}

# Remove default registry key for KMS host - we need to activate with MSFT
# RemoveKMSRegistryKey
	
# Install Volume Activation feature	
Install-WindowsFeature VolumeActivation

# Set the product key and activate
If ($Site.kms.activate)
{
	SetVolumeLicenseKey -Key $Site.kms.hostkey -Verbose
}
