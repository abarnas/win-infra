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
	[psobject]$SQLServer=$null,

	[Parameter(Mandatory=$false)]
	[psobject]$Topology=$null,

	[Parameter(Mandatory=$false)]
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
# Build the install parameter string
function GetInstallParameters
{
	$config = $SQLServer.config
	$productkey = $config.pid
	$securitymode = $config.securitymode
	$sapwd = $config.sapwd
	$features = $config.features
	
	# Set the startup type of each service
	$sqlsvcstartuptype = "Automatic"
	if ($config.sqlsvcstartuptype) { $sqlsvcstartuptype = $config.sqlsvcstartuptype	} 
	
	$agtsvcstartuptype = "Automatic"
	if ($config.agtsvcstartuptype) { $agtsvcstartuptype = $config.agtsvcstartuptype	}
	
	$issvcstartuptype = "Automatic"
	if ($config.issvcstartuptype) {	$issvcstartuptype = $config.issvcstartuptype }
	
	$rssvcstartuptype = "Automatic"
	if ($config.rssvcstartuptype) { $rssvcstartuptype = $config.rssvcstartuptype }
		
	# Determine collation
	if ($config.sqlcollation) {
		$sqlcollation = $config.sqlcollation
	} else {
		$sqlcollation = "SQL_Latin1_General_CP1_CI_AS"
	}
		

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
	"/INDICATEPROGRESS=0 " + `
	"/PID=$productkey " + `
	"/IACCEPTSQLSERVERLICENSETERMS " + `
	"/FEATURES=$features " + `
	"/ADDCURRENTUSERASSQLADMIN=0 " + `
	"/NPENABLED=0 " + `
	"/BROWSERSVCSTARTUPTYPE=" + """Disabled"" " + `
	"/AGTSVCSTARTUPTYPE=" + """$agtsvcstartuptype"" " + `
	"/SQLSVCSTARTUPTYPE=" + """$sqlsvcstartuptype"" " + `
	"/RSSVCSTARTUPTYPE=" + """$rssvcstartuptype"" " + `
	"/ISSVCSTARTUPTYPE=" + """$issvcstartuptype"" " + `
	"/SAPWD=" + """$sapwd"" " + `
	"/SECURITYMODE=$securitymode " + `
	"/SQLCOLLATION=" + """$sqlcollation"" " + `
	"/TCPENABLED=1 "
	
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
	
	# Set the backup target
	if ($Placement -eq "standalone") 
	{
		# Use a local backup target
		$backupTarget = $config.sqlbackupdir
		
		# Make sure the directory exists
		if (-Not(Test-Path $backupTarget)) {
			New-Item $backupTarget -type Directory
		}
	} 
	else 
	{
		$backupTarget = "\\" + $SQLServer.servicehost.hostname + "\" + $SQLServer.servicehost.backupsharename
		if ($SQLServer.config.backupfolder)
		{
			$backupTarget += "\" + $SQLServer.config.backupfolder
		}
	}
	$arguments += "/SQLBACKUPDIR=" + """$backupTarget"" " + "/ASBACKUPDIR=" + """$BackupTarget\Olap"" "
	
	# Set the instance name and id
	if ($config.instancename) 
	{
		$instancename = $config.instancename
		$arguments += "/INSTANCENAME=" + """$instancename"" " + "/INSTANCEID=" + """$instancename"" "
	} 
	else 
	{
		$arguments += "/INSTANCENAME=" + """MSSQLSERVER"" " + "/INSTANCEID=" + """MSSQLSERVER"" "
	}

	
	# If a service account was provided use it, otherwise let SQL use the default SYSTEM account
	if ($SQLServer.serviceaccount.username)
	{
		if (!($SQLServer.serviceaccount.password))
		{
			Throw "SQL service account username was given, but service account password is missing!"
		}
		
		$sqlsvcpassword = $SQLServer.serviceaccount.password
		$sqlsvcaccount = $AccountPrefix + $SQLServer.serviceaccount.username
		
		$arguments += "/SQLSVCACCOUNT=" + """$sqlsvcaccount"" " + "/SQLSVCPASSWORD=" + """$sqlsvcpassword"" "
		$arguments += "/AGTSVCACCOUNT=" + """$sqlsvcaccount"" " + "/AGTSVCPASSWORD=" + """$sqlsvcpassword"" "
		$arguments += "/RSSVCACCOUNT=" + """$sqlsvcaccount"" " + "/RSSVCPASSWORD=" + """$sqlsvcpassword"" "
		$arguments += "/ISSVCACCOUNT=" + """$sqlsvcaccount"" " + "/ISSVCPASSWORD=" + """$sqlsvcpassword"" "
	}


	# Set the SQL server administrator accounts
	$computerName = $env:COMPUTERNAME
	$localAdmin = $computerName + "\Administrator"

	if ($config.sqlsysadminaccounts)
	{
		$adminaccounts = $config.sqlsysadminaccounts.Split(",")
		$arguments += " /SQLSYSADMINACCOUNTS="
		foreach ($account in $adminaccounts) {
			$arguments += """$account"" "
		}
		$arguments += """$localAdmin"" "
		$arguments += """$sqlsvcaccount"" "
	}
	else
	{
		$arguments += " /SQLSYSADMINACCOUNTS=" + """$localAdmin"" "
		$arguments += """$sqlsvcaccount"" "
	}
	
	return $arguments
}

#----------------------------------------------------------------------------------------------
# Install SQL Server
function InstallSQLServer
{
	# Create domain credentials
	$credential = GetCredential

	# Check the install source is valid
	try
	{
		# Set source intall folder
		$source = $Repository.source
		$sourcefolder = Join-Path "\\$source" $Repository.sqlsourcefolder
		
		# Map network drive using domain credentials
		Write-Host "Mapping drive X: to $sourcefolder"
		$unc = New-PSDrive -Name X -PSProvider FileSystem -Credential $credential -Root $sourcefolder
		$command = $unc.Name + ":\" + "setup.exe"
		$command = Join-Path $sourcefolder "setup.exe"
		$sqltestpath = $unc.Name + ":\x64\Setup\sql_tools.msi"
		Write-Host "Setting install source to $command"

		# Make sure the source path exists
		Write-Host "Testing path: $command"
		if (!(Test-Path $command))
		{
			Throw "Error installing SQL Server because install source $command not found!"
		}

		# Make sure we're actually pointing to a SQL install location and not something else
		Write-Host "Testing path $sqltestpath"
		if (!(Test-Path "$sqltestpath"))
		{
			Throw "Error installing SQL Server because the install media is not a SQL Server install media!"
		}
		
		# Create the support folder for log results
		Write-Host "Creating C:\Support\SQLInstall.log"
		if (!(Test-Path "C:\Support"))
		{
			New-Item "C:\Support" -type Directory
		}
	}
	catch
	{
		$linenr = $_.InvocationInfo.ScriptLineNumber
		$line = $_.InvocationInfo.Line
		Throw "Error setting install source path at line $linenr - $line. $($_.Exception.Message)"
	}

		
	# Get the install parameters
	$arguments = GetInstallParameters
	$arguments
	
	# Install SQL Server
	try
	{
		# Set up the script to invoke 
		$scriptBlockContent = {
			param($command,$arguments)
			$result = 0
			$process = Start-Process -FilePath $command -ArgumentList $arguments -PassThru -Wait -RedirectStandardOutput "C:\Support\SQLInstall.log" 
			$result = $process.ExitCode
			if (!($result -eq 0) -And $result -ne $null)
			{
				$linenr = $_.InvocationInfo.ScriptLineNumber
				$line = $_.InvocationInfo.Line
				Throw "Error installing SQL Server at line $linenr - $line. $($_.Exception.Message)"
			}
		}

		# Invoke the command
		Write-Verbose "Starting SQL Server installation"
		$computerName = $env:COMPUTERNAME
		invoke-command -ComputerName $computerName `
		               -Credential $credential `
					   -Authentication CredSSP `
					   -ScriptBlock $scriptBlockContent `
					   -ArgumentList $command,$arguments
	}
	catch
	{
		$linenr = $_.InvocationInfo.ScriptLineNumber
		$line = $_.InvocationInfo.Line
		Throw "Error installing SQL Server at line $linenr - $line. $($_.Exception.Message)"
	}
}

#----------------------------------------------------------------------------------------------

function GetCredential
{
	if ($Placement -eq "standalone")
	{
		# Configure credentials for standalone installation
		$userName = $env:ComputerName + "\Administrator"
	}
	else
	{
		# Configure credentials for domain installation
		$userName = $Domain.netbiosname + "\Administrator"
	}
	
	# Build the credentials object
	$password = ConvertTo-SecureString $Domain.password -AsPlaintext -Force
	$Credential = New-Object -typename System.Management.Automation.PSCredential -argumentlist $userName, $password
	Write-Host "Using user account $userName / $password"
	
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
	$AccountPrefix = $Domain.netbiosname + "\"
	if (-Not($SQLServer.servicehost.hostname)) { Throw "Error: missing SQLServer.servicehost.hostname parameter!" }
}
elseif ($Placement -eq "domain")
{
	Write-Verbose "Active Directory placement set to Domain"
	$Domain = $Topology.domain
	$AccountPrefix = $Domain.netbiosname + "\"
	if (-Not($SQLServer.servicehost.hostname)) { Throw "Error: missing SQLServer.servicehost.hostname parameter!" }
}
else
{
	Write-Verbose "Placement set to standalone in WORKGROUP"
	$AccountPrefix = ".\"
}

# Make sure we have all the parameters that we need
if (-Not ($SQLServer.config.pid)) { Throw "Error: missing SQLServer.config.pid parameter!" }
if (-Not ($SQLServer.config.features)) { Throw "Error: missing SQLServer.config.features parameter!" }
if (-Not ($Domain.password)) { Throw "Error: missing domainPassword parameter in Domain!" }
if (-Not ($Domain.netbiosname)) { Throw "Error: missing netbiosname parameter in Domain!" }
if (-Not ($Repository.source)) { Throw "Error: missing Source parameter in Repository!" }
if (-Not ($Repository.sqlsourcefolder)) { Throw "Error: missing sqlsourcefolder parameter in Repository!" }

# Make sure we run as admin            
$usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()            
$IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                               
if (-not($IsAdmin))            
{            
	Throw "Must run powerShell as Administrator to perform these actions"     
}

# Run main functions
CheckFrameworkVersion("3.5")

#Install SQL Server
InstallSQLServer
