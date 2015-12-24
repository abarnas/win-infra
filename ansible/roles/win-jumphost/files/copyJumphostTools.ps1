#------------------------------------------------------------------------------------------------------------
# Script  : /roles/win-jumphost/copyJumphostTools.ps1
# Purpose : Copy the necessary jumphost tools from the repo image
#-------------------------------------------------------------------------------------------------------------

# Parameters
[CmdletBinding()]
Param(
	[Parameter(Mandatory)]
	[psobject]$Repository=$null
)

#----------------------------------------------------------------------------------------------
# Copy the tools
function CopyTools
{
	try
	{
		# Create a network object
		$net = New-Object -com WScript.Network

		# Test if the drive is already mapped. If it is, remove it.
		$drive = "X:"
		if (Test-Path $drive)
		{
			$net.RemoveNetworkDrive($drive)
		}

		# Build the install source
		$installSource = $Repository.source
		$copySource = $Repository.toolssourcefolder
		
		# Map the network drive
		$net.mapnetworkdrive($drive, "\\$installSource", $true, $userName, $password)
		
		# Create the support folder for log results
		$TargetFolder = "C:\Support"
		if (-Not(Test-Path "$TargetFolder"))
		{
			New-Item "$TargetFolder" -type Directory
		}

		# Start copy process
		$sourcePath = $drive + "\" + "$copySource"
		Copy-Item -Path "$sourcePath" -Destination "$TargetFolder" -Recurse -Force
		$net.RemoveNetworkDrive($drive)
	}
	catch
	{
		$linenr = $_.InvocationInfo.ScriptLineNumber
		$line = $_.InvocationInfo.Line
		Throw "Error copying $SourcePath to $TargetFolder at line $linenr - $line. $($_.Exception.Message)"
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
if (-Not ($Repository.source)) { Throw "Error: missing Repository.source.features parameter!" }
if (-Not ($Repository.toolssourcefolder)) { Throw "Error: missing Repository.toolssourcefolder.features parameter!" }

# Make sure we run as admin            
$usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()            
$IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                               
if (-not($IsAdmin))            
{            
	Throw "Must run powerShell as Administrator to perform these actions"     
}

# Run main functions
CopyTools



	
