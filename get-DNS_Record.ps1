<#
	.SYNOPSIS
		Identifies DNS Records
	
	.NOTES
		Script Name:	get-DNS_Record.ps1
		Created By: 	Gavin Townsend
		Date: 			August 2019
		
	.DESCRIPTION
		The script performs the follow actions:
			- Public DNS resolution of SOA and MX records
		
	.EXAMPLE
			.\get-DNS_Record.ps1
			
	.REQUIREMENTS
		
		Public resolution alternative  https://mxtoolbox.com/
		
	.AUDIT CRITERIA
		Complete a discovery of SOA and MX records
			
		Note the following exceptions
			- SOA records that are not 'cscdns.net'
			- MX records that are not 'mimecast.com'
			
	.VERSION HISTORY
		1.0		Aug 2019	Gavin Townsend		Original Build
		2.0		Feb 2020	Gavin Townsend		Updated to public resolution and built in checks
		
#>

$Domain = Read-Host 'Enter public domain name'
$Type = @('SOA','MX')
$Log = "C:\Temp\Audit\$Domain DNS Scan $(get-date -f yyyy-MM-dd).txt"

Function Get-PublicDnsRecord{
    Param(
        [Parameter(Mandatory=$true,Position=1)]
        [String]$DomainName,

        [Parameter(Mandatory=$true,Position=2)]
        [ValidateSet('A','AAAA','CERT','CNAME','DHCIP','DLV','DNAME','DNSKEY','DS','HINFO','HIP','IPSECKEY','KX','LOC','MX','NAPTR','NS','NSEC','NSEC3','NSEC3PARAM','OPT','PTR','RRSIG','SOA','SPF','SRV','SSHFP','TA','TALINK','TLSA','TXT')]
        [String[]]$DnsRecordType
    )
    Begin{}
    Process{
        ForEach($Record in $DnsRecordType){
            Try{
                $WebUrl = 'http://www.dns-lg.com/opendns1/{0}/{1}' -f $DomainName,$Record
                
                $WebData = Invoke-WebRequest $WebUrl -ErrorAction Stop | Select-Object -ExpandProperty Content | ConvertFrom-Json | Select-Object -ExpandProperty answer
                $WebData | % {
                     New-Object -TypeName PSObject -Property @{
                        'Name'      = $_.name
                        'Type'      = $_.type
                        'Target'    = $_.rdata
                    }
                }
            }
            catch{
                Write-Warning -Message $_
                New-Object -TypeName PSObject -Property @{
                    'Name'      = $DomainName
                    'Type'      = $Record
                    'Target'    = ($_[0].ErrorDetails.Message -split '"')[-2]
                }
            }
        }
    }
    End{}
}

#Lookup and Log
$Record = Get-PublicDnsRecord -DomainName $Domain -DnsRecordType $Type
$Record | Out-File $Log

write-Host ""
write-Host "---------------------------------------------------"
write-Host "Script Output Summary - DNS Scan for $Domain $(Get-Date)"
write-Host ""

if ($Record -like '*cscdns.net*') {
	write-host "DNS Provider is CSC" -foregroundcolor green
}
Else{
	write-host "DNS Provider is not CSC" -foregroundcolor yellow
}

if ($Record -like '*mimecast*') {
	write-host "Mail Provider is Mimecast" -foregroundcolor green
}
Else{
	write-host "DNS Provider is not Mimecast" -foregroundcolor yellow
}
write-Host ""
write-Host "---------------------------------------------------"
write-host ""
write-host "DNS scanning tests concluded. Please review $Log" 
write-host ""
$Record
