########################################################################################################
# Script  : checkPorts.ps1
#
# Purpose : Test an array of TCP and UDP ports and see if they are opened up
# Author  : Ard-Jan Barnas
# Date    : 5/9/2015
# Inputs  : TargetSystem  : Remote host to check
#			TestPorts	  : Dictionary containing list of UDP and TCP ports
#           PortqryPath   : Location of portqry.exe (optional - uses %path% to \windows\system32\cis)
#			(see common.yml)
#
########################################################################################################

# Parameters
[CmdletBinding()]
Param(
	[Parameter(Mandatory)]
	[string]$TargetSystem=$null,
	
	[Parameter(Mandatory)]
	[psobject]$TestPorts=$null,

	[Parameter(Mandatory=$false)]
	[psobject]$PortqryPath=$null
)

#----------------------------------------------------------------------------------------------

function IsAvailable
{
	# First let's see if the server is available
	If (Test-Connection -comp $TargetSystem -count 2 -quiet) 
	{ 
		Write-Host "$TargetSystem is available"
		return $true
	}

	Write-Warning "$TargetSystem unreachable. Check if it is on and ICMP port is opened!"
	Exit 1
}
	
#----------------------------------------------------------------------------------------------

function CheckPorts
{  

	[string[]]$PortsTCP = $TestPorts.PortsTCP.Split(",")
	foreach ($port in $PortsTCP)
	{
		Write-Host "Testing port TCP $port..."

		$cmd = "portqry -n " + $TargetSystem + " -e " + $port + " -p TCP"
		$output = Invoke-Expression $cmd
		$output = $output | where {$_}
		$result = $output[-1]
		
		if ($result -match "\bLISTENING\b")
		{
			Write-Verbose "Connection to port UDP $port successfull!"
		}
		else
		{
			Write-Warning "Connection to port UDP $port failed: $result"
			Exit 1
		}
	}

	[string[]]$PortsUDP = $TestPorts.PortsUDP.Split(",")
	foreach ($port in $PortsUDP)
	{
		Write-Host "Testing port UDP $port..."

		$cmd = "portqry -n " + $TargetSystem + " -e " + $port + " -p UDP"
		$output = Invoke-Expression $cmd
		$output = $output | where {$_}
		$result = $output[-1]
		
		if ($result -match "\bLISTENING\b")
		{
			Write-Host "Connection to port UDP $port successfull!"
		}
		else
		{
			Write-Warning "Connection to port UDP $port failed: $result"
			Exit 1
		}
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

# Make sure we have all the parameters that we need
if (-Not($TargetSystem)) { Throw "missing TargetSystem" }
if (-Not($TestPorts)) { Throw "missing TestPort dictionary" }

# Check ports
If (IsAvailable)
{
	CheckPorts
}

