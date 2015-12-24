#------------------------------------------------------------------------------------------------------------
# Script  : /roles/win-scomgateway/approveSCOMGateway.ps1
# Purpose : Create a new availability group
#
# Inputs  : 
#-------------------------------------------------------------------------------------------------------------

# Parameters
[CmdletBinding()]
Param(
	[Parameter(Mandatory)]
	[string]$Placement=$null,

	[Parameter(Mandatory)]
	[string]$Gateway=$null,

	[Parameter(Mandatory)]
	[psobject]$SCOM=$null,

	[Parameter(Mandatory=$false)]
	[psobject]$Topology=$null,
	
	[Parameter(Mandatory=$false)]
	[psobject]$Repository=$null
)

#----------------------------------------------------------------------------------------------
Function GetHostName($ip)
{
	try
	{
		$ipAddress = $ip
		$ipObj = [System.Net.IPAddress]::parse($ipAddress)
		$isValidIP = [System.Net.IPAddress]::tryparse([string]$ipAddress, [ref]$ipObj)
	}
	catch
	{
		$isValidIP = $False
	}
	
	if ($isValidIP) 
	{
        write-host "checking $ip"
		$hostname = ([System.Net.Dns]::gethostentry($ip)).hostname
		if (!($hostname))
		{
			# hostname not found
			Throw "Error: hostname lookup failed for ip $ip!"
		}
		
		return $hostname
	} 
		
	$hostname = $ip
	return $hostname
}

#----------------------------------------------------------------------------------------------
Function ApproveSCOMGateway
{
	# Prepare approval tool copy locations
	$share = "\\" + $Repository.source
	$filename = $Repository.scomapprovaltool
	${dest} = Join-Path $SCOM.installdrive "\Program Files\Microsoft System Center 2012 R2\Operations Manager\Setup"
	
	# Prepare command to execute
	$command = Join-Path $dest $filename
	
	# Set gateway and management server names
	$managementserver = $SCOM.primarymgmtserver.hostname 
	$gatewayserver = $Gateway
	$gatewayserver += "." + $Domain.domainname
	Write-Log "Setting gateway server $gatewayserver"

	try
	{
		if (-Not(Test-Path $command))
		{
			# Get the credential object
			Write-Log "Getting domain account credentials"
			$credential = GetDomainCredential
			
			Write-Log "Mapping drive R to $share"
			New-PSDrive -Name R -root $share -PSProv FileSystem -Credential $credential
			
			Write-Log "Using source $sourcefolder\$filename"
			$sourcefolder = Join-Path "R:" $Repository.scomsupporttoolsfolder
			${source} = Join-Path $sourcefolder $filename
			
			# Copy the GatewayApprovalTool files to the install directory
			Write-Log "Copying ${source} to ${dest}"
			Copy-Item "${source}" -Destination "${dest}" -Force
			
			Write-Log "Copy completed. Removing drive R"
			Remove-PSDrive R
		}
		
		if (Test-Path $command)
		{
			Write-Log "Approving $gatewayserver on $managementserver"
			$command = "D:\Program Files\Microsoft System Center 2012 R2\Operations Manager\Setup\Microsoft.EnterpriseManagement.GatewayApprovalTool.exe"
			$arguments = "/ManagementServerName=alln-p3-scom01.cisinfra.local /GatewayName=mel-s1-scom01.mgmt.cisinfra.local /Action=Create"

			# Get SCOM credentials
			$credential = GetSCOMCredential

			# Set up the script to invoke 
			$scriptBlockContent = {
				param($command,$arguments)

				$args = "/c " + """$command""" + " " + $arguments
				$result = (Start-Process -FilePath "c:\windows\system32\cmd.exe" -ArgumentList "$args" -PassThru -Wait).ExitCode

#				$result = (Start-Process -FilePath "cmd /c $command" -ArgumentList $arguments -PassThru -Wait).ExitCode
				if (!($result -eq 0) -And $result -ne $null)
				{
					$linenr = $_.InvocationInfo.ScriptLineNumber
					$line = $_.InvocationInfo.Line
					Throw "Error $result installing SCOM gateway. Check $logfile for details"
				}
			}

			# Invoke the command
			Write-Log "Starting SCOM Gateway approval: $command $arguments"
			invoke-command -ComputerName $env:COMPUTERNAME `
						   -Credential $credential `
						   -Authentication CredSSP `
						   -ScriptBlock $scriptBlockContent `
						   -ArgumentList $command,$arguments
		}
		else
		{
			Throw "Invalid path to SCOM approval tool: $command!"
		}
	}
	catch
	{
		$linenr = $_.InvocationInfo.ScriptLineNumber
		$line = $_.InvocationInfo.Line
		Throw "Error approving SCOM gateway at line $linenr - $line. $($_.Exception.Message)"
	}
}

#----------------------------------------------------------------------------------------------

function GetSCOMcredential
{
	# Build the credentials object
	$SCOMusername = $Topology.forest.netbiosname + "\" + $SCOM.actionaccount.username
	$SCOMPassword = $SCOM.actionaccount.password | ConvertTo-SecureString -AsPlaintext -Force
	$SCOMCredential = New-Object -typename System.Management.Automation.PSCredential -argumentlist $SCOMUsername, $SCOMPassword
	
	return $SCOMCredential
}

#----------------------------------------------------------------------------------------------

function GetForestCredential
{
	# Build the credentials object
	$forestusername = $Topology.forest.netbiosname + "\administrator"
	$forestPassword = $Topology.forest.password | ConvertTo-SecureString -AsPlaintext -Force
	$forestCredential = New-Object -typename System.Management.Automation.PSCredential -argumentlist $forestUsername, $forestPassword
	
	return $forestCredential
}

#----------------------------------------------------------------------------------------------

function GetDomainCredential
{
	# Build the credentials object
	$domainUserName = $Domain.netbiosname + "\administrator"
	$domainPassword = $Domain.password | ConvertTo-SecureString -AsPlaintext -Force
	$DomainCredential = New-Object -typename System.Management.Automation.PSCredential -argumentlist $domainUserName, $domainPassword
	
	return $DomainCredential
}

#----------------------------------------------------------------------------------------------

function Write-Log($content)
{
	$logPath = "C:\Support\ansible.log"

	Write-Verbose $content
	
	$logcontent = "{0} - $content" -f (Get-Date).ToString("hh:mm:ss")
	Add-Content -Path $logPath -Value $logcontent -Force
}

#----------------------------------------------------------------------------------------------
# Setup error handling.
$VerbosePreference = "Continue"

Trap
{
	$_
    Exit 1
}
$ErrorActionPreference = "Stop"

#----------------------------------------------------------------------------------------------
# Main
#----------------------------------------------------------------------------------------------

# Set the domain dictionary to use
if ($Placement -eq "forest") 
{
	Write-Log "Active Directory placement set to Forest"
	$Domain = $Topology.forest
}
elseif ($Placement -eq "domain")
{
	Write-Log "Active Directory placement set to Domain"
	$Domain = $Topology.domain
}
else
{
	Throw "Invalid domain placement specified. Must be domain or forest!"
}

# Make sure we have all the parameters that we need
if (-Not ($Gateway)) { Throw "Error: missing gateway parameter!" }
if (-Not ($Repository.scomsupporttoolsfolder)) { Throw "Error: missing Repository.scomsupporttoolsfolder parameter!" }
if (-Not ($Repository.scomapprovaltool)) { Throw "Error: missing Repository.scomapprovaltool parameter!" }

# Make sure we run as admin            
$usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()            
$IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                               
if (-not($IsAdmin))            
{            
	Throw "Must run powerShell as Administrator to perform these actions"     
}

# Approve the SCOM Gateway
ApproveSCOMGateway 