#------------------------------------------------------------------------------------------------------------
# Script  : /roles/win-sqlserver/addSQLStartupParameter.ps1
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
# Add startup parameter
function addSQLStartupParameter
{
	# Startup parameter is optional. If not set return...
	if (-Not ($SQLServer.sqlstartupflags))	{
		return
	}
	
	$StartupParameter = $SQLServer.sqlstartupflags
	
	try
	{
		$hklmRootNode = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server"

		$props = Get-ItemProperty "$hklmRootNode\Instance Names\SQL"
		$instances = $props.psobject.properties | ?{$_.Value -like 'MSSQL*'} | select Value

		$instances | %{
			$inst = $_.Value;
			$regKey = "$hklmRootNode\$inst\MSSQLServer\Parameters"
			$props = Get-ItemProperty $regKey
			$params = $props.psobject.properties | ?{$_.Name -like 'SQLArg*'} | select Name, Value
			#$params | ft -AutoSize
			$hasFlag = $false
			
			foreach ($param in $params) 
			{
				if($param.Value -eq $StartupParameter) 
				{
					$hasFlag = $true
					break;
				}
			}
			if (-not $hasFlag) 
			{
				"Adding $StartupParameter"
				$newRegProp = "SQLArg"+($params.Count)
				Set-ItemProperty -Path $regKey -Name $newRegProp -Value $StartupParameter
			} 
			else 
			{
				"$StartupParameter already set"
			}
		}
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

# Make sure we run as admin            
$usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()            
$IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                               
if (-not($IsAdmin))            
{            
	Throw "Must run powerShell as Administrator to perform these actions"     
}

# Run main functions
if ($SQLServer.sqlstartupflags)
{
	addSQLStartupParameter
}


