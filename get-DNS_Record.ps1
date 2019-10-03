<#
	.SYNOPSIS
		Identifies DNS Records
	
	.NOTES
		Script Name:	get-DNS_Record.ps1
		Created By: 	Gavin Townsend
		Date: 			August 2019
		
	.DESCRIPTION
		The script performs the follow actions:
			- Promtps for domain and record type to search for
			- Internal DNS resolution
			- Public DNS resolution
		
	.EXAMPLE
			.\get-DNS_Record.ps1
			
	.REQUIREMENTS
		Resolve DNS-Name needs Powershell v4 (Windows 8.1/2012R2) or later
		
		Public resolution alternative  https://mxtoolbox.com/
		
	.AUDIT CRITERIA
		Complete a discovery of SOA and MX records
			
		Note the following exceptions
			- SOA records that are not 'cscdns.net'
			- MX records that are not 'mimecast.com'
			
	.VERSION HISTORY
		1.0		Aug 2019	Gavin Townsend		Original Build
		
#>


$Domain = Read-Host 'Enter public domain name'
$Type = Read-Host 'Enter Record Type (eg A, SOA, MX)'
$Log = "C:\Temp\Audit\$Domain DNS $Type $(get-date -f yyyy-MM-dd).txt"

Write-host "Attempting internal DNS resolution"
Resolve-DnsName $Domain -type $Type >> $Log

Write-host "Attempting public DNS resolution"
Resolve-DnsName $Domain -type $Type -server 8.8.8.8 >> $Log

write-host ""
write-host "Log Export Complete to $Log" -foregroundcolor yellow
