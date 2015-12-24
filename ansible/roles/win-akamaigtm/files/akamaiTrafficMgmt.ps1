#-------------------------------------------------------------------------------------------------------
# Script  : /roles/akamaigtm/akamaiTrafficMmgmt.ps1
# Purpose : Manage Akamai configuration for KMS purposes
#
# Input   : Authentication and Site hashable objects
#-------------------------------------------------------------------------------------------------------

# Parameters
[CmdletBinding()]
Param(
	[Parameter(Mandatory)]
	[psobject]$Authentication=$null,
	
	[Parameter(Mandatory)]
	[psobject]$Site=$null
)

#------------------------ AKAMAI POST/GET ---------------------------------------------------

# Generate HMAC SHA256 Base64
Function Crypto ($secret, $message)
{
	[byte[]] $keyByte = [System.Text.Encoding]::ASCII.GetBytes($secret)
	[byte[]] $messageBytes = [System.Text.Encoding]::ASCII.GetBytes($message)
	$hmac = new-object System.Security.Cryptography.HMACSHA256((,$keyByte))
	[byte[]] $hashmessage = $hmac.ComputeHash($messageBytes)
	$Crypt = [System.Convert]::ToBase64String($hashmessage)
	
	return $Crypt
}

#----------------------------------------------------------------------------------------------

# Calls to AkamaiOPEN API
function Invoke-AkamaiOPEN
{
    param(
	    [Parameter(Mandatory=$true)]
	    [string]$Method, 
	
	    [Parameter(Mandatory=$true)]
	    [string]$ClientToken, 
	
	    [Parameter(Mandatory=$true)]
	    [string]$ClientAccessToken, 
	
	    [Parameter(Mandatory=$true)]
	    [string]$ClientSecret, 
	
	    [Parameter(Mandatory=$true)]
	    [string]$ReqURL, 
	
	    [Parameter(Mandatory=$false)]
	    [string]$Body
    )

    
    #ReqURL Verification
    If (($ReqURL -as [System.URI]).AbsoluteURI -eq $null -or $ReqURL -notmatch "luna.akamaiapis.net") 
    {    
	    throw "Error: Invalid Request URI: '$ReqURL'"
    } 

    #Body Verification
#    If (($Body -ne $null))
#    {

#	    $Body_Size = [System.Text.Encoding]::Unicode.GetByteCount($Body)
#	    If (($Body_Size -gt $allowedBodySize))
#	    {
#		    throw "Error: Body size greater than maximum allowed($allowedBodySize bytes)"
#	    }
#
#       write-host "Writing $Body_Size bytes"
#    }

    #Sanitize Method param
    $Method = $Method.ToUpper()

    #Split $ReqURL for inclusion in SignatureData
    $ReqArray = $ReqURL -split "(.*\/{2})(.*?)(\/)(.*)"

    #Timestamp for request signing
    #$TimeStamp = [DateTime]::UtcNow.ToString("yyyyMMddTHH:mm:sszz00")
    
    # Use Akamai's time service to guarantee accurate time
    $TimeStamp = Invoke-RestMethod -Method GET -Uri "http://time.akamai.com/?iso"
    $timestamp = [datetime]$TimeStamp
    $timestamp = [System.TimeZoneInfo]::ConvertTimeToUtc($timestamp)
    $timestamp = $TimeStamp.ToString("yyyyMMddTHH:mm:sszz00")

    #GUID for request signing
    $Nonce = [GUID]::NewGuid()

    #Build data string for signature generation
    $SignatureData = $Method + "`thttps`t"
    $SignatureData += $ReqArray[2] + "`t" + $ReqArray[3] + $ReqArray[4]

    if (($Body -ne $null) -and ($Method -ceq "POST"))
    {
	    $Body_SHA256 = [System.Security.Cryptography.SHA256]::Create()
	    $Post_Hash = [System.Convert]::ToBase64String($Body_SHA256.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($Body.ToString())))
	
	    $SignatureData += "`t`t" + $Post_Hash + "`t"
    }
    else
    {
	    $SignatureData += "`t`t`t"
    }

    $SignatureData += "EG1-HMAC-SHA256 "
    $SignatureData += "client_token=" + $ClientToken + ";"
    $SignatureData += "access_token=" + $ClientAccessToken + ";"
    $SignatureData += "timestamp=" + $TimeStamp  + ";"
    $SignatureData += "nonce=" + $Nonce + ";"

    #Generate SigningKey
    $SigningKey = Crypto -secret $ClientSecret -message $TimeStamp

    #Generate Auth Signature
    $Signature = Crypto -secret $SigningKey -message $SignatureData

    #Create AuthHeader
    $AuthorizationHeader = "EG1-HMAC-SHA256 "
    $AuthorizationHeader += "client_token=" + $ClientToken + ";"
    $AuthorizationHeader += "access_token=" + $ClientAccessToken + ";"
    $AuthorizationHeader += "timestamp=" + $TimeStamp + ";"
    $AuthorizationHeader += "nonce=" + $Nonce + ";"
    $AuthorizationHeader += "signature=" + $Signature

    #Create IDictionary to hold request headers
    $Headers = @{}

    #Add Auth header
    $Headers.Add('Authorization',$AuthorizationHeader)

    #Add additional headers if POSTing or PUTing
    If (($Method -ceq "POST") -or ($Method -ceq "PUT"))
    {
        $Body_Size = [System.Text.Encoding]::UTF8.GetByteCount($Body)
	    $Headers.Add('max-body',$Body_Size)
	    $Headers.Add('Content-Type','application/json')
    }


    #Check for valid Methods and required switches
    If (($Method -ceq "POST") -and ($Body -ne $null))
    {
	    #Invoke API call with POST and return
	    $ErrorActionPreference = 'SilentlyContinue'
        Try
        {
	        Invoke-RestMethod -Method $Method -Uri $ReqURL -SessionVariable api
        }
	    Catch
        {
        }

        $api.Headers.set_Item('Expect', '')
	    $ErrorActionPreference = 'Continue'

        try
        {
	        Invoke-RestMethod -Method $Method -WebSession $api -Uri $ReqURL -Headers $Headers -Body $Body
        }
        catch
        {
            $result = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($result)
            $responseBody = $reader.ReadToEnd();
            Throw $responseBody
        }
    }
    elseif  (($Method -ceq "PUT") -and ($Body -ne $null))
    {
	    #Invoke API call with PUT and return
        try
        {
	        Invoke-RestMethod -Method $Method -Uri $ReqURL -Headers $Headers -Body $Body
        }
        catch
        {
            $result = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($result)
            $responseBody = $reader.ReadToEnd();
            Throw $responseBody
        }
    }
    elseif (($Method -ceq "GET") -or ($Method -ceq "DELETE"))
    {
	    #Invoke API call with GET or DELETE and return
        try
        {
	        Invoke-RestMethod -Method $Method -Uri $ReqURL -Headers $Headers
        }
        catch
        {
            $result = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($result)
            $responseBody = $reader.ReadToEnd();
            Throw $responseBody
        }
    }
    else
    {
	    throw "Error: Invalid -Method specified or missing required parameter"
    }
}

#----------------------------------------------------------------------------------------------

# Perform a GET operation
function GetResult([string]$uri)
{
    write-host $uri
    return Invoke-AkamaiOPEN -Method GET -ReqURL $uri -ClientToken $authentication.clientToken -ClientSecret $authentication.clientSecret -ClientAccessToken $authentication.clientAccessToken
}

#----------------------------------------------------------------------------------------------

# Perform a DELETE operation
function DeleteResult([string]$uri)
{
    write-host $uri

    if ($debugMode)
    {
        # Do nothing
        return
    }

    return Invoke-AkamaiOPEN -Method DELETE -ReqURL $uri -ClientToken $authentication.clientToken -ClientSecret $authentication.clientSecret -ClientAccessToken $authentication.clientAccessToken
}

#----------------------------------------------------------------------------------------------

# perform a POST operation
function PostResult([string]$uri, [object]$body)
{
    write-host $uri

    if ($debugMode)
    {
        return $body
    }

    $data = $body | ConvertTo-Json -Depth 5 -Compress
    return Invoke-AkamaiOPEN -Method POST -ReqURL $uri -Body $data -ClientToken $authentication.clientToken -ClientSecret $authentication.clientSecret -ClientAccessToken $authentication.clientAccessToken
}

#----------------------------------------------------------------------------------------------

# perform a PUT operation
function PutResult([string]$uri, [object]$body)
{
    write-host $uri

    if ($debugMode)
    {
        return $body
    }

    $data = $body | ConvertTo-Json -Depth 5 -Compress
    return Invoke-AkamaiOPEN -Method PUT -ReqURL $uri -Body $data -ClientToken $authentication.clientToken -ClientSecret $authentication.clientSecret -ClientAccessToken $authentication.clientAccessToken
}


#------------------------ DOMAIN ---------------------------------------------------


# Get a domain object
function GetDomain([object]$domains, [string]$domainName)
{
    $domain = $domains.items | ? { $_.name -eq $domainName }
    if (-Not ($domain))
    {
        Write-Warning "domain $Site.domainName not found!"
        Exit 1
    } 

    return GetResult($domain.links.href)
}


#------------------------ DATACENTER ---------------------------------------------------


# Get datacenter object using nickname
function GetDatacenterByNickname([object]$domain, [string]$key)
{
	$dc = $domain.datacenters | ? {$_.nickname -eq $key}
	if (-Not ($dc))
	{
        # datacenter not found under the primary list. Try looking
        # in datacenter.resources
	    $dc = $domain.datacenters.resource | ? {$_.nickname -eq $key}
        if (-Not ($dc))
        {
        }
    }

    return $dc
}

#----------------------------------------------------------------------------------------------

# Get datacenterId by datacenter nickName
function GetDatacenterIDByNickname([object]$domain, [string]$key)
{
    Write-Host "Locating datacenterId for $key"

    $dc = $domain.datacenters | ? {$_.nickname -eq $key}
	if (-Not ($dc))
	{
        # Datacenter not found under the primary list. 
        # -------------------------------------------
        # When saving a datacenter object, Akamai stores the object in a temporary
        # "resources" object. Try looking in resources for the datacenter object
        $dc = $domain.datacenters.resource | ? {$_.nickname -eq $key}
        if (-Not ($dc))
        {
            Write-Warning "datacenter $key doesn't exist!"
            Exit 1
        }
	}

    $id = $dc.datacenterId
    return $id
}

#----------------------------------------------------------------------------------------------

# Save datacenter object
function SaveDatacenter([object]$dc, [bool]$isNew)
{
    Write-Host "Saving datacenter..."
    $href = $urlDatacenters.href

	if (-Not ($isNew))
	{
        # We're updating the datacenter. Add the datacenterId to the URL
        $href += "/" + $dc.datacenterId
    	return PutResult $href $dc
	}

	return PostResult $href $dc
}

#----------------------------------------------------------------------------------------------

# Delete datacenter
function DeleteDatacenter([object]$domain)
{
    $dc = $domain.datacenters | ? {$_.nickname -eq $Site.sitename}
    if ($dc)
    {
        # Remove datacenter online
        $href = $urlDatacenters.href + "/" + $dc.datacenterId
        $result = DeleteResult $href

        # Remove the datacenter from the array in memory
        $domain.datacenters = $domain.datacenters | where {$_.nickname -ne $Site.sitename}

        return $result
    }
}

#----------------------------------------------------------------------------------------------

# Create/update datacenter object
function CreateDatacenter([object]$domain)
{
    $dc = $domain.datacenters | ? {$_.nickname -eq $Site.sitename}
    if ($dc)
    {
        # Update datacenter
        $dc.nickname = $Site.sitename
        $dc.city = $Site.datacenter.city
        $dc.continent = $Site.datacenter.continent
        $dc.country = $Site.datacenter.country
        
        if ($Site.datacenter.latitude) {
            $dc.latitude = $Site.datacenter.latitude
        } 

        if ($Site.datacenter.longitude) {
            $dc.longitude = $Site.datacenter.longitude
        } 

        # Save datacenter object
    	return SaveDataCenter $dc $false
    }

    # Build a new datacenter object
    $dc = @{}
    $dc.Add('nickname', $Site.sitename)
    $dc.Add('city', $Site.datacenter.city)
    $dc.Add('continent', $Site.datacenter.continent)
    $dc.Add('country', $Site.datacenter.country)
    $dc.Add('latitude', $Site.datacenter.latitude)
    $dc.Add('longitude', $Site.datacenter.longitude)

    if ($debugMode){
        $dc.Add('datacenterId', 3999)
    }

    # Save the datacenter first. We need the datacenterId to be returned!
    $dc = SaveDataCenter $dc $true
    $domain.datacenters += ($dc | ConvertTo-Json -Depth 5 | ConvertFrom-Json)
	$datacenterCreated = $true
    return $dc
}

#------------------------ TRAFFIC TARGETS ---------------------------------------------------

# Retrieve trafficTarget object.
function GetTrafficTarget([object]$property, [string]$key)
{
	$target = $property.trafficTargets | ? {$_.datacenterId -eq $key}
	if (-Not ($target))
	{
        Write-Warning "trafficTarget with ID $key doesn't exist!"
        Exit 1
	}

    return $target
}

#----------------------------------------------------------------------------------------------

# Create trafficTargets
function BuildTrafficTargets([object]$domain)
{
    # Get the datacenter ID
    $id = GetDataCenterIDByNickname $domain $Site.sitename

    # Build the trafficTargets array
    $trafficTargets = @()

    # Build new primary trafficTarget object
    $trafficTarget = @{}
    $traffictarget.Add('datacenterId', $id)
    $traffictarget.Add('enabled', $true)
    $traffictarget.Add('weight', 1.0)
    $traffictarget.Add('servers', @($Site.kms.vip))

    # Add trafficTarget to the list of trafficTargets
    $trafficTargets += $trafficTarget

    # Add the backup traffic targets (must be two existing datacenters)
	if ($Site.kms.backupsites) 
	{
		foreach ($backupSite in $Site.kms.backupsites)
		{
			$id = GetDataCenterIDByNickname $domain $backupSite
			$target = $domain.properties.traffictargets | ? {$_.datacenterId -eq $id -And $_.servers -And $_.weight -eq "1.0"}

			$trafficTarget = @{}
			$traffictarget.Add('datacenterId', $id)
			$traffictarget.Add('enabled', $true)
			$traffictarget.Add('weight', 0.0)
			$traffictarget.Add('servers', @($target.servers))

			# Add trafficTarget to the list of trafficTargets
			$trafficTargets += $trafficTarget
		}
	}
	
    return $trafficTargets
}


#------------------------ LIVENESS TESTS ---------------------------------------------------


# Create liveness test
function BuildLivenessTest([object]$domain)
{
    # Build the livenessTests array
    $livenessTests = @()

    # Add the primary liveness test
    $livenessTest = @{}
    $livenessTest.Add('name', 'Liveness')
    $livenessTest.Add('testObjectPort', $Site.kms.port)
    $livenessTest.Add('testObjectProtocol','TCP')
    $livenessTest.Add('testInterval', 60)
    $livenessTest.Add('testTimeout', 10)

    # Add livenessTest to the list of livenessTests
    $livenessTests += $livenessTest

    return $livenessTests
}


#------------------------ PROPERTIES ---------------------------------------------------


# Retrieve property object.
function GetPropertyByName([object]$domain, [string]$key)
{
	$prop = $domain.properties | ? {$_.name -eq $key}
	if (-Not ($prop))
	{
        Write-Warning "property $key doesn't exist!"
        Exit 1
	}

    return $prop
}


#----------------------------------------------------------------------------------------------

# Save property object
function SaveProperty([object]$property)
{
    Write-Host "Saving property..."

    $href = $urlProperties.href + "/" + $property.name
    return PutResult $href $property
}


#----------------------------------------------------------------------------------------------

# Remove property
function DeleteProperty([object]$domain)
{
    $property = $domain.properties | ? {$_.name -eq $Site.sitename}
    if ($property)
    {
        # Remove the online property
        $href = $urlProperties.href + "/" + $property.name
        $result = DeleteResult $href

        # Remove the property from the domain in memory
        $domain.properties = $domain.properties | where {$_.name -ne $Site.sitename}

        return $result
    }
}

#----------------------------------------------------------------------------------------------

# Create property
function CreateProperty([object]$domain)
{
    $livenessTests = BuildLivenessTest $domain
    $trafficTargets = BuildTrafficTargets $domain
    
    $property = $domain.properties | ? {$_.name -eq $Site.sitename}
    if (-Not ($property))
    {
        # Create new property object
        $property = @{}
        $property.Add('name', $Site.sitename)
        $property.Add('handoutMode', 'normal')
        $property.Add('failoverDelay', 0)
        $property.Add('failbackDelay', 0)
        $property.Add('type', 'failover')
        $property.Add('scoreAggregationType', 'worst')
        $property.Add('staticTTL', 300)
        $property.Add('dynamicTTL', 300)

        $property.Add('trafficTargets', @($trafficTargets))
        $property.Add('livenessTests', @($livenessTests))

        # Save property
        $property = SaveProperty $property
		$propertyCreated = $true

        # Add the Property object to the domain
        $domain.properties += ($property | ConvertTo-Json -Depth 5 | ConvertFrom-Json)
        return $property
    }


    # Update Property object
    $property.trafficTargets = @($trafficTargets)
    $property.livenessTests = @($livenessTests)
    return SaveProperty $property
}


# ---------------------------------------------------------------------------------
# Remove Cidr Property TrafficTarget (!!)
#
# Removing zones from the cidrMap object leaves the map object for that zone
# behind in the primary mao "cidr". We need to remove that.
#-----------------------------------------------------------------------------------

function DeleteCidrPropertyTrafficTarget([object]$domain)
{
    # Get the property object
    $property = GetPropertyByName $domain $authentication.cidrPropertyName

    # Remove the trafficTarget from the list
    $handoutCname = $Site.sitename + "." + $authentication.domainName

    # See if the trafficTarget was created
    $trafficTarget = $property.trafficTargets | ? {$_.handoutCName -ne $handoutCName}
    if ($trafficTarget)
    {
        Write-Host "Found trafficTarget with name $handoutCName. Removing..."

        # Find the property index
        $ix = $domain.properties.IndexOf($property)

        # trafficTarget was created. Allow rollback to remove it
       	$property.trafficTargets = $property.trafficTargets | ? {$_.handoutCName -ne $handoutCName}

        # update the properties in memory
        $domain.properties[$ix] = $property

        # Save Property object
        return SaveProperty $property
    }

    return $property
}

# ---------------------------------------------------------------------------------
# Create/Update Cidr Property TrafficTarget (!!)
#
# Adding zones to the cidrMap object causes a new trafficTarget object for that zone
# to be created under the "cidr" property, but it will be missing the handoutCName
# We need to add that here.
#-----------------------------------------------------------------------------------

function UpdateCidrPropertyTrafficTarget([object]$domain)
{
    # Get the datacenter ID
    $id = GetDataCenterIDByNickname $domain $Site.sitename

    # Get the property object
    $property = GetPropertyByName $domain $authentication.cidrPropertyName


   	$target = $property.trafficTargets | ? {$_.datacenterId -eq $id}
	if (-Not ($target))
	{
        # Create trafficTarget
        $trafficTarget = @{}
        $trafficTarget.Add('datacenterId', $id)
        $trafficTarget.Add('enabled', $true)
        $trafficTarget.Add('weight', 1.0)
        $trafficTarget.Add('handoutCName', $Site.sitename + "." + $authentication.domainName)

        $property.trafficTargets += ($trafficTarget | ConvertTo-Json -Depth 5 | ConvertFrom-Json)
		$trafficTargetCreated = $true
    }
    else
    {
        # Update the traffic target
        $ix = $property.trafficTargets.IndexOf($target)
        $property.trafficTargets[$ix].handoutCName = $Site.sitename + "." + $authentication.domainName
        $property.trafficTargets[$ix].enabled = $true
        $property.trafficTargets[$ix].weight = 1.0
    }

    # Save Property object
    return SaveProperty $property
}

#------------------------ CIDR MAPS ---------------------------------------------------

function GetCidrMapByDatacenter([object]$domain, [string]$id)
{
    $map = $domain.cidrmaps.assignments | ? {$_.datacenterId -eq $id}
    if (-Not ($map))
    {
        Write-Warning "CIDR Map for $id doesn't exist!"
        Exit 1
    }

    return $map
}

#----------------------------------------------------------------------------------------------

function GetCidrMapByNickName([object]$domain, [string]$name)
{
    $map = $domain.cidrmaps.assignments | ? {$_.nickname -eq $name}
    if (-Not ($map))
    {
        Write-Warning "CIDR Map for $id doesn't exist!"
        Exit 1
    }

    return $map
}

#----------------------------------------------------------------------------------------------

# Save cidrMap object
function SaveCidrMap([object]$domain, [object]$map)
{
    Write-Host "Saving cidrMap: $map"

    $href = $urlCidrMaps.href + "/" + $authentication.cidrMapName
    return PutResult $href $map
}

#----------------------------------------------------------------------------------------------

# Remove cidrMap assignment
function DeleteCidrMap([object]$domain)
{
    # Find the assignment with the Site sitename
    $assignment = $domain.cidrMaps.assignments | ? {$_.nickname -eq $Site.sitename}

    # If the assignment was found, remove it
    if ($assignment)
    {
        # Remove the assignment from the cidrMap in memory
        $assignments = $domain.cidrMaps.assignments | where {$_.nickname -ne $Site.sitename}

        # Copy the existing cidrMap values in the new cidrMap object
        $map = @{}
        $map.name = $domain.cidrmaps.name
        $map.assignments = @($assignments)
        $map.defaultDatacenter = $domain.cidrmaps.defaultDatacenter

        # Update the in memory cidr map
        $domain.cidrMaps = ($map | ConvertTo-Json -Depth 5 | ConvertFrom-Json)

        # Save the online cidr map
        return SaveCidrMap $domain $map
    }
}

#----------------------------------------------------------------------------------------------

# Build the Cidr Map
function CreateCidrMap([object]$domain)
{
    # get the list of assignments
    $assignments = $domain.cidrMaps.assignments
    
    # attempt to find the assignment with the Site sitename
    $assignment = $assignments | ? {$_.nickname -eq $Site.sitename}

    if (-Not ($assignment))
    {
        # Get the datacenterId
        $id = GetDataCenterIDByNickname $domain $Site.sitename

        # Create a new cidrMap assignment object
        $assignment = @{
            nickname = $Site.sitename
            datacenterId = $id
            blocks = @($cidrMap)
        }

        # Add assigment to list of assignments
        $assignments += $assignment
    }
    else
    {
        # Update the list of cidr addresses
        $assignment.blocks = @($cidrMap)
    }

    # Copy the existing cidrMap values in the new cidrMap object
    $map = @{}
    $map.name = $domain.cidrmaps.name
    $map.assignments = @($assignments)
    $map.defaultDatacenter = $domain.cidrmaps.defaultDatacenter

    $domain.cidrMaps = ($map | ConvertTo-Json -Depth 5 | ConvertFrom-Json)
	$cidrMapCreated = $true

    return SaveCidrMap $domain $map
}

# --------------------------------------------------------------------------------------------
# Rollback function
#
# If any part of the create/update process fails, the rollback function is invoked, removing
# any components/objects created prior to the failure.
# --------------------------------------------------------------------------------------------

function Rollback()
{
	if ($cidrMapCreated -Or $action -eq "remove")
    { 
        Write-Host "Removing cidr map..."
        DeleteCidrMap $kmsDomain 
    }

    if ($trafficTargetCreated -Or $action -eq "remove") 
    { 
        Write-Host "Removing trafficTarget from primary cidr map..."
        DeleteCidrPropertyTrafficTarget $kmsDomain 
    }

    if ($propertyCreated -Or $action -eq "remove") 
    { 
        Write-Host "Removing domain property..."
        DeleteProperty $kmsDomain 
    }

    if ($datacenterCreated -Or $action -eq "remove") 
    { 
        Write-Host "Removing datacenter..."
        DeleteDatacenter $kmsDomain 
    }
}

#----------------------------------------------------------------------------------------------
# Main
#----------------------------------------------------------------------------------------------

# Enable verbose output
$VerbosePreference = "Continue"

# Set ErrorActionPreference
$ErrorActionPreference = "Continue"

# Setup error handling.
Trap
{
    Write-Error $_
    Write-Warning "Error occured. Rolling back..."
    Rollback
    Exit 1
}

#----------------------------------------------------------------------------------------------

# Make sure we have all the required values. If one or more values are missing, exit

# Validate Authentication parameters
if (-Not ($authentication.clientToken)) { Throw "Error: missing clientToken parameter in Authentication!" }
if (-Not ($authentication.clientAccessToken)) { Throw "Error: missing clientAccessToken parameter in Authentication!" }
if (-Not ($authentication.clientSecret)) { Throw "Error: missing cleintSecret parameter in Authentication!"	}
if (-Not ($authentication.baseAddress)) { Throw "Error: missing baseAddress parameter in Authentication!" }
if (-Not ($authentication.rootAddress)) { Throw "Error: missing rootAddress parameter in Authentication!" }
if (-Not ($authentication.domainName)) { Throw "Error: missing domainName parameter in Authentication!" }
if (-Not ($authentication.cidrMapName)) { Throw "Error: missing cidrMapName parameter in Authentication!" }
if (-Not ($authentication.CidrPropertyName)) { Throw "Error: missing CidrPropertyName parameter in Authentication!" }

# Validate Site parameters
if (-Not ($Site.sitename)) { Throw "Error: missing siteName parameter in Site!" }
if (-Not ($Site.subnets)) { Throw "Error: missing subnets parameter in Site!" }
if (-Not ($Site.subnets.servicecloud)) { Throw "Error: missing subnets.servicecloud parameter in Site!" }
if (-Not ($Site.subnets.tenantcloud)) { Throw "Error: missing subnets.tenantcloud parameter in Site!" }
#if (-Not ($Site.subnets.internaldns)) { Throw "Error: missing subnets.internaldns parameter in Site!" }
if (-Not ($Site.kms.port)) { Throw "Error: missing kmsport parameter in Site!" }
if (-Not ($Site.kms.vip)) { Throw "Error: missing kmsvip parameter in Site!"	}
if (-Not ($Site.kms.backupsites)) { Throw "Error: missing kmsBackupSites parameter in Site!" }
if (-Not ($Site.datacenter.city)) { Throw "Error: missing City parameter in Site.datacenter!" }
if (-Not ($Site.datacenter.continent)) { Throw "Error: missing continent parameter in Site.datacenter!" }
if (-Not ($Site.datacenter.country)) { Throw "Error: missing country parameter in Site.datacenter!" }

#----------------------------------------------------------------------------------------------

# Build the array of subnets for the cidr map
$cidrMap = @()
$cidrMap += $Site.subnets.servicecloud
$cidrMap += $Site.subnets.tenantcloud

if ($Site.subnets.internaldns) {
	$cidrMap += $Site.subnets.internaldns
}

# debug mode - won't save objects to Akamai
$debugMode = $false
$action = "create"

$datacenterCreated = $false
$propertyCreated = $false
$cidrMapCreated = $false
$trafficTargetCreated = $false

# Retrieve the domains
$domains = GetResult($Authentication.rootAddress)

# Get the KMS domain from the domains hash
$kmsDomain = GetDomain $domains $Authentication.domainName

# Get URLs for each section
$urlDatacenters = $kmsDomain.links | ? { $_.rel -eq 'datacenters' }
$urlProperties = $kmsDomain.links | ? { $_.rel -eq 'properties' }
$urlGeographicmaps = $kmsDomain.links | ? { $_.rel -eq 'geographic-maps' }
$urlCidrMaps = $kmsDomain.links | ? { $_.rel -eq 'cidr-maps' }
$urlResources = $kmsDomain.links | ? { $_.rel -eq 'resources' }


if ($action -eq "remove")
{
    Rollback
}
else
{
    # Create/update Datacenter object
    Write-Host "Creating Datacenter..."
    $datacenter = CreateDataCenter($kmsDomain)
    write-host $datacenter.datacenterId

    # Create/update Property object
    Write-Host "Creating Property..."
    $property = CreateProperty($kmsDomain)

    # Create/update CidrMap object
    Write-Host "Creating Cidr Map..."
    $cidrMaps = CreateCidrMap($kmsDomain)

    # Update root Cidr Property
    Write-Host "Updating Cidr Property"
    UpdateCidrPropertyTrafficTarget($kmsDomain)
}
