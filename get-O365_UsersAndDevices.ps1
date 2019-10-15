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


$Domain = $(get-addomain).dnsroot
$UserLog = "C:\Temp\Audit\$Domain O365 User List $(get-date -f yyyy-MM-dd).csv"
$PCLog = "C:\Temp\Audit\$Domain O365 Device List $(get-date -f yyyy-MM-dd).csv"

$Users = get-msoluser -all | Select-Object IsLicensed,UserPrincipalName,@{Name="PrimaryEmailAddress";Expression={$_.ProxyAddresses | ?{$_ -cmatch '^SMTP\:.*'}}},FirstName,LastName,Office,Department,Title,@{Name='Created';Expression={$_.WhenCreated.ToString("yyyy\/MM\/dd")}} 
$users | export-csv $UserLog -NoTypeInformation

$uCount = $users.count
Write-Host "User report complete for $uCount user objects in $Domain. Details exported to $UserLog"


$Devices = Get-MsolDevice -All | Select Enabled,DisplayName,DeviceOsType,DeviceOsVersion,DeviceTrustType,DeviceTrustLevel,ApproximateLastLogonTimestamp
$Devices | export-csv $PCLog -NoTypeInformation

$cCount = $Devices.count
Write-Host "Computer report complete for $cCount computer objetcs in $Domain. Details exported to $PCLog"


