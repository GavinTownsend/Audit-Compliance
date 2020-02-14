<#
	.SYNOPSIS
		Exports a basic list of Computer and User Objects
	
	.NOTES
		Script Name:	get-O365_UsersAndDevices.ps1
		Created By:		Gavin Townsend
		Date:			October 2019
		
	.DESCRIPTION
		The script performs the follow actions:
			- Exports a list of baisc User data from Azure AD 
			- Exports a list of baisc Computer data from Azure AD 
		
	.EXAMPLE
			.\get-O365_UsersAndDevices.ps1
			
	.REQUIREMENTS
		O365 PowerShell plugins https://docs.microsoft.com/en-us/office365/enterprise/powershell/connect-to-office-365-powershell
		
			Install-Module MSOnline
		
		#Connect as a Non MFA enabled user
			$AdminCred = Get-Credential admin@example.com
			Connect-MsolService -Credential $AdminCred

		#Connect as an MFA enabled user (login GUI)
			Connect-MsolService
			
		Global administrator role

	.AUDIT CRITERIA
		Complete a discovery scan of users and computers in Azure AD
			
		Make a note of total numbers for comparison with other test cases
			
	.VERSION HISTORY
		1.0		Oct 2019	Gavin Townsend		Original Build
		
#>


Try{$Domain = $(get-addomain).dnsroot}
Catch{$Domain = ""}

$UserLog = "C:\Temp\Audit\$Domain O365 User List $(get-date -f yyyy-MM-dd).csv"
$PCLog = "C:\Temp\Audit\$Domain O365 Device List $(get-date -f yyyy-MM-dd).csv"

$Users = get-msoluser -all | Select-Object IsLicensed,UserPrincipalName,@{Name="PrimaryEmailAddress";Expression={$_.ProxyAddresses | ?{$_ -cmatch '^SMTP\:.*'}}},FirstName,LastName,Office,Department,Title,@{Name='Created';Expression={$_.WhenCreated.ToString("yyyy\/MM\/dd")}} 
$uCount = $users.count
$users | export-csv $UserLog -NoTypeInformation -Encoding UTF8

$Devices = Get-MsolDevice -All | Select Enabled,DisplayName,DeviceOsType,DeviceOsVersion,DeviceTrustType,DeviceTrustLevel,ApproximateLastLogonTimestamp
$dCount = $Devices.count
$Devices | export-csv $PCLog -NoTypeInformation -Encoding UTF8


write-Host ""
write-Host "---------------------------------------------------"
write-Host "Script Output Summary - O365 Users and Devices $(Get-Date)"
write-Host ""
write-Host "User count: $uCount"
write-Host "Device count: $dCount"
write-Host ""
write-Host "---------------------------------------------------"
write-Host ""
Write-Host "User scanning tests concluded. Please review log $UserLog"
Write-Host "Device scanning tests concluded. Please review log $PCLog"
