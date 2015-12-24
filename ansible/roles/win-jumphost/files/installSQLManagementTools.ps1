#------------------------------------------------------------------------------------------------------------
# Script  : /roles/win-jumphost/installSQLManagementTools.ps1
# Purpose : Install SQL server management tools
#-------------------------------------------------------------------------------------------------------------

# Parameters
[CmdletBinding()]
Param(
	[Parameter(Mandatory)]
	[psobject]$SQLServer=$null,

	[Parameter(Mandatory)]
	[psobject]$Repository=$null
)

#----------------------------------------------------------------------------------------------
# Make sure .NET Framework 3.5 is installed
function CheckFrameworkVersion([string]$version)
{
	$feature = Get-WindowsFeature | Where DisplayName -eq ".NET Framework $version Features"
	if (-Not($feature.installed))
	{
		Throw "Error installing SQL Server: .NET Framework 3.5 is not installed!"
	}
}

#----------------------------------------------------------------------------------------------
# Install SQL Server
function InstallSQLServer
{
	$computerName = $env:COMPUTERNAME
	$localAdmin = $computerName + "\Administrator"
	$SQLServerConfig = $SQLServer.config
	
	$installSource = Join-Path $Repository.source $Repository.sqlsourcefolder
	$command = "\\$installSource" + "\setup.exe"
	Write-Verbose "Setting install source to $command"

	# Make sure the source path exists
	if (!(Test-Path $command))
	{
		Throw "Error installing SQL Server because install source $command not found!"
	}

	# Create the support folder for log results
	if (!(Test-Path "C:\Support"))
	{
		New-Item "C:\Support" -type Directory
	}
	
	$productkey = $SQLServerConfig.pid
	$features = $SQLServerConfig.features

	# Build the install parameter list
	$arguments = "/ACTION=Install " + `
	"/ENU=1 " + `
	"/QUIET=1 " + `
	"/QUIETSIMPLE=0 " + `
	"/UpdateEnabled=0 " + `
	"/UpdateSource=" + """MU"" " + `
	"/HELP=0 " + `
	"/X86=0 " + `
	"/SQMREPORTING=0 " + `
	"/FILESTREAMLEVEL=0 " + `
	"/ENABLERANU=0 " + `
	"/ERRORREPORTING=0 " + `
	"/INDICATEPROGRESS " + `
	"/PID=$productkey " + `
	"/IACCEPTSQLSERVERLICENSETERMS " + `
	"/FEATURES=$features "

	# Set the install and data directories
	if ($config.installshareddir) {
		$installshareddir = $config.installshareddir
		$arguments += "/INSTALLSHAREDDIR=" + """$installshareddir"" "
	}
	if ($installsharedwowdir) {
		$installsharedwowdir = $config.installsharedwowdir
		$arguments += "/INSTALLSHAREDWOWDIR=" + """$installsharedwowdir"" "
	}
	if ($config.instancedir) {
		$instancedir = $config.instancedir
		$arguments += "/INSTANCEDIR=" + """$instancedir"" " + "/INSTALLSQLDATADIR=" + """$instancedir"" "
	}

	# Install SQL Server
	try
	{
		Start-Process -FilePath $command -ArgumentList $arguments -PassThru -Wait -RedirectStandardOutput "C:\Support\SQLInstall.log" 
	}
	catch
	{
		$linenr = $_.InvocationInfo.ScriptLineNumber
		$line = $_.InvocationInfo.Line
		Throw "Error installing SQL Server at line $linenr - $line. $($_.Exception.Message)"
	}
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

# Make sure we have all the parameters that we need
if (-Not ($SQLServer.config.pid)) { Throw "Error: missing SQLServer.config.pid parameter!" }
if (-Not ($SQLServer.config.features)) { Throw "Error: missing SQLServer.config.features parameter!" }
if (-Not ($Repository.source)) { Throw "Error: missing Repository.source.features parameter!" }
if (-Not ($Repository.sqlsourcefolder)) { Throw "Error: missing Repository.sqlsourcefolder.features parameter!" }

# Make sure we run as admin            
$usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()            
$IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                               
if (-not($IsAdmin))            
{            
	Throw "Must run powerShell as Administrator to perform these actions"     
}

# Run main functions
CheckFrameworkVersion("3.5")
InstallSQLServer


	
