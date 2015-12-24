#------------------------------------------------------------------------------------------------------------
# Script  : /roles/win-sqlserver/configureSQLInstancePort.ps1
# Purpose : Install SQL server
#
# Inputs  : Cluster, Domain
#-------------------------------------------------------------------------------------------------------------

# Parameters
[CmdletBinding()]
Param(
	[Parameter(Mandatory)]
	[psobject]$SQLServer=$null
)

#----------------------------------------------------------------------------------------------
# Configure SQL TCP Port
function IsNumeric($value)
{
	$ErrorActionPreference = "SilentlyContinue"

	try
	{
		$num = 0 + $value
		$ErrorActionPreference = "Stop"
		return $true
	}
	catch
	{
		$ErrorActionPreference = "Stop"
		Throw "Error: port number $value is not a number!"
	}
}

#----------------------------------------------------------------------------------------------
# Configure SQL TCP Port
function configureSQLInstancePort
{
	# Get current computerName
	$computerName = $env:ComputerName
	
	# Determine the instance and service names
	if(-Not($SQLServer.config.instancename) -Or $SQLServer.config.instancename -eq "MSSQLSERVER")
	{
		$instname = "MSSQLSERVER"
		$SQLServicename = "MSSQLSERVER"
		$AgentServiceName = "SQLSERVERAGENT"
	}
	else
	{
		$instname = $SQLServer.config.instancename
		$SQLServicename = "MSSQL$" + $SQLServer.config.instancename
		$AgentServiceName = "SQLAgent$" + $SQLServer.config.instancename
	}

	# Make sure the port number is a numeric value
	if (IsNumeric($SQLServer.config.instanceport))
	{
		try
		{
			# Load the assemblies
			[system.reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null
			[system.reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement") | Out-Null

			$mc = new-object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer $computerName
			$i = $mc.ServerInstances[$instname]
			
			# Select the TCP protocol
			$p = $i.ServerProtocols['Tcp']
			
			# Select IP-All 
			$ip = $p.IPAddresses['IPAll']
			
			# Clear the dynamic value
			$ip.IPAddressProperties['TcpDynamicPorts'].Value = ''
			
			# Select the TCP Port property
			$ipa = $ip.IPAddressProperties['TcpPort']
			
			# Set the instance port number
			$ipa.Value = [string]$SQLServer.config.instanceport

			# Submit the changes
			Write-Host "Setting new SQL port"
			$p.Alter()
			
			# Restart the services
			Write-Host "Restarting SQL and Agent service"
			$s = Get-Service $SQLServicename
			$s.restart
			
			$s = Get-Service $AgentServiceName
			$s.restart
		}
		catch
		{
			$linenr = $_.InvocationInfo.ScriptLineNumber
			$line = $_.InvocationInfo.Line
			Throw "Error setting the port number at line $linenr - $line. $($_.Exception.Message)"
		}
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
if (-Not ($SQLServer.config)) { Throw "Error: missing SQLServer.config parameter!" }

# Make sure we run as admin            
$usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()            
$IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                               
if (-not($IsAdmin))            
{            
	Throw "Must run powerShell as Administrator to perform these actions"     
}

#Install SQL Server
if ($SQLServer.config.instanceport -And -Not($SQLServer.config.instanceport -eq 1433))
{
	configureSQLInstancePort
}

