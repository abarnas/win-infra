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
# Install SCOM Gateway
function InstallSCOMGateway
{
	# Set the command line to execute
	$command = $Repository.logpath + "\SCOM\" + $Repository.scomgatewaysourcefile
	$logpath = $Repository.logpath
	
	# Make sure the source path exists
	Write-Host "Testing path: $command"	
	if (!(Test-Path $command))
	{
		Throw "Error: install source $command not found!"
	}

	# Check target install drive
	if (-Not(Test-Path $SCOM.gateway.installdrive))
	{
		Throw "Error: specified target install drive doesn't exist!"
	}
		
	# Set the parameters
	$logfile = Join-Path $Repository.logpath "SCOMGatewayInstall.log"
	$managementgroup = $SCOM.managementgroup
	$managementserver = $SCOM.primarymgmtserver.hostname
	$managementport=$SCOM.managementport
	$domainname = $Domain.netbiosname
	$actionaccount = $SCOM.actionaccount.username
	$actionPassword = $SCOM.actionaccount.password
	$installdir = Join-Path $SCOM.gateway.installdrive "\Program Files\Microsoft\System Center Operations Manager"

	# Build the argument list
	$arguments = "/qn /i $command /l*v $logfile " + `
	"ADDLOCAL=MOMGateway " + `
	"MANAGEMENT_GROUP=" + """$managementgroup"" " + `
	"IS_ROOT_HEALTH_SERVER=0 " + `
	"ROOT_MANAGEMENT_SERVER_AD=$managementserver " + `
	"ROOT_MANAGEMENT_SERVER_DNS=$managementserver " + `
	"ACTIONS_USE_COMPUTER_ACCOUNT=0 " + `
	"ACTIONSDOMAIN=$domainname " + `
	"ACTIONSUSER=$actionAccount " + `
	"ACTIONSPASSWORD=$actionPassword " + `
	"ROOT_MANAGEMENT_SERVER_PORT=$managementport " + `
	"INSTALLDIR=" + """$installdir"" " + `
	"AcceptEndUserLicenseAgreement=1"
	
	# Install software
	try
	{
		# Set up the script to invoke 
		$scriptBlockContent = {
			param($arguments)
			
			$result = (Start-Process -FilePath "msiexec" -ArgumentList $arguments -PassThru -Wait).ExitCode
			if (!($result -eq 0) -And $result -ne $null)
			{
				$linenr = $_.InvocationInfo.ScriptLineNumber
				$line = $_.InvocationInfo.Line
				Throw "Error $result installing SCOM gateway. Check $logfile for details"
			}
		}

		# Get the credential object
		$credential = GetDomainCredential
		
		# Invoke the command
		Write-Host "Starting SCOM Gateway installation"
		Write-Host $arguments
		invoke-command -ComputerName $env:COMPUTERNAME `
		               -Credential $credential `
					   -Authentication CredSSP `
					   -ScriptBlock $scriptBlockContent `
					   -ArgumentList $arguments
	}
	catch
	{
		$linenr = $_.InvocationInfo.ScriptLineNumber
		$line = $_.InvocationInfo.Line
		Throw "Error installing SCOM Gateway at line $linenr - $line. $($_.Exception.Message)"
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
if (-Not ($SCOM.secondarymgmtserver.hostname)) { Throw "Error: missing SCOM.secondarymgmtserver.hostname parameter!" }
if (-Not ($SCOM.managementgroup)) { Throw "Error: missing SCOM.managementgroup parameter!" }
if (-Not ($SCOM.managementport)) { Throw "Error: missing SCOM.managementport parameter!" }
if (-Not ($Domain.netbiosname)) { Throw "Error: missing netbiosname parameter in Domain!" }
if (-Not ($Repository.source)) { Throw "Error: missing Source parameter in Repository!" }
if (-Not ($Repository.logpath)) { Throw "Error: missing logpath parameter in Repository!" }
if (-Not ($Repository.scomgatewaysourcefolder)) { Throw "Error: missing scomgatewaysourcefolder parameter in Repository!" }
if (-Not ($Repository.scomgatewaysourcefile)) { Throw "Error: missing scomgatewaysourcefile parameter in Repository!" }

# Make sure we run as admin            
$usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()            
$IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                               
if (-not($IsAdmin))            
{            
	Throw "Must run powerShell as Administrator to perform these actions"     
}

#Install SQL Server
InstallSCOMGateway

