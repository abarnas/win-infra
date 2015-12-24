#------------------------------------------------------------------------------------------------------------
# Script  : /roles/win-sqlserver/EnableSQLFailoverClustering.ps1
# Purpose : Configure SQL Server to enable failover clustering
#
# Inputs  : 
#-------------------------------------------------------------------------------------------------------------

# Parameters
[CmdletBinding()]
Param(
	[Parameter(Mandatory)]
	[psobject]$SQLServer=$null
)

#----------------------------------------------------------------------------------------------
# Enable clustering
function EnableSQLFailoverClustering
{
	$server = $env:COMPUTERNAME
	$path = "SQLSERVER:\SQL\$server\"
	if (-Not($SQLServer.config.instancename -eq "MSSQLSERVER")) {
		$path += $SQLServer.config.instancename
	} else {
		$path += "DEFAULT"
	}
		
	try
	{
		# Enable AlwaysOn. We use the -Force option to force a server restart without confirmation.
		# This WILL result in your SQL Server instance restarting.
		Write-Verbose "Enabling AlwaysOn on server instance: $server"
		Enable-SqlAlwaysOn -Path $path -Force
	}
	catch
	{
		$linenr = $_.InvocationInfo.ScriptLineNumber
		$line = $_.InvocationInfo.Line
		Throw "Error enabling SQL AlwaysOn availability at line $linenr - $line. $($_.Exception.Message)"
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
if (-Not ($SQLServer.config)) { Throw "Error: missing SQLServer config parameter!" }

# Make sure we run as admin            
$usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()            
$IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                               
if (-not($IsAdmin))            
{            
	Throw "Must run powerShell as Administrator to perform these actions"     
}

# Import SQL powershell module
Import-Module "sqlps" -DisableNameChecking

# Run main functions
EnableSQLFailoverClustering


	
