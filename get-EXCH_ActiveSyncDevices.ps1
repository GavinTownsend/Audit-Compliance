<#
	.SYNOPSIS
		Gets a list of Exchange ActiveSync devicdes
	
	.NOTES
		Script Name:	get-EXCH_ActiveSyncDevices.ps1
		Created By: 	Gavin Townsend
		Date: 			August 2019
		
	.DESCRIPTION
		The script performs the follow actions:
			- Collects mobile devices and statistics			
		
	.EXAMPLE
			.\get-EXCH_ActiveSyncDevices.ps1
			
	.REQUIREMENTS
		Exchange Management Tools PowerShell plugin
	
	.AUDIT CRITERIA
		Complete a discovery scan of ActiveSync devices in Exchange
			
		Make a note of total numbers for comparison with MDM test case
			
	.VERSION HISTORY
		1.0		Aug 2019	Gavin Townsend		Original Build
		
#>
Try{$Domain = $(get-addomain).dnsroot}
Catch{$Domain = ""}

$Log = "C:\temp\Audit\$Domain ActiveSync Devices $(get-date -f yyyy-MM-dd).csv"

$AllDevices = Get-MobileDevice -result unlimited | Get-MobileDeviceStatistics
$AllDeviceCount = $AllDevices.count
Write-host "Mobile device count is $AllDeviceCount"

$AllDevices | Export-Csv $Log -notype -Encoding UTF8
Write-Host "Export completed to $Log"
