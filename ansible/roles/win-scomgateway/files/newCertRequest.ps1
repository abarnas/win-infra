############################################################################################################
## Generate a certificate and signing request                                                             ##
## ------------------------------------------------------------------------------------------------------ ##
## Offline mode to create a request with a single name (Subject Only)                                     ##
## EXAMPLE:                                                                                               ##
## New-CertificateRequest -subject CN=<new-cert-name>                                                     ##
## New-CertificateRequest -subject CN=scom-gateway,DC=cisinfra,DC=local                                   ##
## New-CertificateRequest -subject CN=scom-gateway.cisinfra.local                                         ##
## ------------------------------------------------------------------------------------------------------ ##
## Offline mode to create a request with a subject and SANs                                               ##
## EXAMPLE:                                                                                               ##   
## New-CertificateRequest -subject CN=<new-cert-name> -SANs <new-sans-name>                               ##
## New-CertificateRequest -subject CN=scom-gateway,DC=cisinfra,DC=local -SANs scom-gateway.cisinfra.local ##
## ------------------------------------------------------------------------------------------------------ ##
## Online mode to create a certificate request with SANs, request a certificate authority directly from a ##
## Windows Enterprise Certificate Authority and import the certificate                                    ##
## EXAMPLE:                                                                                               ##
## New-CertificateRequest -subject CN=<new-cert-name> -SANs <new-sans-name> -OnlineCA <ca-name>           ##
## New-CertificateRequest -subject CN=scom-gateway,DC=cisinfra,DC=local `                                 ##
## -SANs scom-gateway.cisinfra.local -OnlineCA adc1.cisinfra.local\cisinfra-ADC1-CA                       ##
############################################################################################################

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
	[switch]$OnlineCA
)


# Generate a new certificate request
function RequestCertificate
{
	$subject = "CN=" + $env:COMPUTERNAME + "." + $Domain.domainname
	$SANs = $env:COMPUTERNAME + "." + $Domain.domainname
	$CATemplate = $SCOM.gateway.catemplate
	$rootCA = $Topology.ca.hostname + $Topology.forest.domainname + "\" + $Topology.ca.rootauthority
	
    # Preparation
    $subjectDomain = $subject.split(',')[0].split('=')[1]
    if ($subjectDomain -match "\*.") {
        $subjectDomain = $subjectDomain -replace "\*", "star"
    }
    $CertificateINI = "C:\Support\$subjectDomain.inf"
    $CertificateREQ = "C:\Support\$subjectDomain.req"
    $CertificateRSP = "C:\Support\$subjectDomain.rsp"
    $CertificateCER = "C:\Support\$subjectDomain.cer"
 
    # INI file generation
	Write-Verbose "Generating INI file"
	
    new-item -type file $CertificateINI -force
#    add-content $CertificateINI '[Version]'
#    add-content $CertificateINI 'Signature="$Windows NT$"'
#    add-content $CertificateINI ''
    add-content $CertificateINI '[NewRequest]'
    $temp = 'Subject="' + $subject + '"'
    add-content $CertificateINI $temp
    add-content $CertificateINI 'Exportable=TRUE'
    add-content $CertificateINI 'KeyLength=2048'
    add-content $CertificateINI 'KeySpec=1'
#    add-content $CertificateINI 'KeyUsage=0xA0'
    add-content $CertificateINI 'KeyUsage=0xf0'
    add-content $CertificateINI 'MachineKeySet=True'
	
	# Below is replaced by this...
	add-content $CertificateINI '[EnhancedKeyUsageExtension]'
	add-content $CertificateINI 'OID=1.3.6.1.5.5.7.3.1'
	add-content $CertificateINI 'OID=1.3.6.1.5.5.7.3.2'
	
#    add-content $CertificateINI 'ProviderName="Microsoft RSA SChannel Cryptographic Provider"'
#    add-content $CertificateINI 'ProviderType=12'
#    add-content $CertificateINI 'SMIME=FALSE'
#    add-content $CertificateINI 'RequestType=PKCS10'
#    add-content $CertificateINI '[Strings]'
#    add-content $CertificateINI 'szOID_ENHANCED_KEY_USAGE = "2.5.29.37"'
#    add-content $CertificateINI 'szOID_PKIX_KP_SERVER_AUTH = "1.3.6.1.5.5.7.3.1"'
#    add-content $CertificateINI 'szOID_PKIX_KP_CLIENT_AUTH = "1.3.6.1.5.5.7.3.2"'

#    if ($SANs) {
#        add-content $CertificateINI 'szOID_SUBJECT_ALT_NAME2 = "2.5.29.17"'
#        add-content $CertificateINI '[Extensions]'
#        add-content $CertificateINI '2.5.29.17 = "{text}"'
 
#        foreach ($SAN in $SANs) {
#            $temp = '_continue_ = "dns=' + $SAN + '&"'
#            add-content $CertificateINI $temp
#        }
#    }
 
    # Certificate request generation
    if (test-path $CertificateREQ) {del $CertificateREQ}
    certreq -new $CertificateINI $CertificateREQ
 
    # Online certificate request and import
    if ($OnlineCA) {
        if (test-path $CertificateCER) {del $CertificateCER}
        if (test-path $CertificateRSP) {del $CertificateRSP}
        certreq -submit -attrib "CertificateTemplate:$CATemplate" -config $OnlineCA $CertificateREQ $CertificateCER
 
        certreq -accept $CertificateCER
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
if (-Not ($Topology.ca)) { Throw "Error: missing Topology.ca parameter!" }
if (-Not ($SCOM.gateway.catemplate)) { Throw "Error: missing SCOM.gateway.catemplate parameter!" }
if (-Not ($Domain.domainname)) { Throw "Error: missing domainname parameter in Domain!" }

# Make sure we run as admin            
$usercontext = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()            
$IsAdmin = $usercontext.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")                               
if (-not($IsAdmin))            
{            
	Throw "Must run powerShell as Administrator to perform these actions"     
}

#Install SQL Server
RequestCertificate
