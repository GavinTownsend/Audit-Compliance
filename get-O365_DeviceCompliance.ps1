<#
	.SYNOPSIS
		Exports a list of O365 device compliance status
	
	.NOTES
		Script Name:	get-O365_DeviceCompliance.ps1
		Created By:		Gavin Townsend
		Date:			October 2019
		
	.DESCRIPTION
		The script performs the follow actions: 
			- Exports a list of Computer compliance data from Azure AD 
		
	.EXAMPLE
			.\get-O365_DeviceCompliance.ps1
			
	.REQUIREMENTS
		O365 PowerShell plugins https://docs.microsoft.com/en-us/office365/enterprise/powershell/connect-to-office-365-powershell
		
		#Connect as a Non MFA enabled user
			$AdminCred = Get-Credential admin@example.com
			Connect-MsolService -Credential $AdminCred

		#Connect as an MFA enabled user (login GUI)
			Connect-MsolService
			
		Global administrator role

	.AUDIT CRITERIA
		Complete a discovery scan of computers in Azure AD
			
		Make a note of devices that are not compliant. (recent login dates show activity)
			
	.VERSION HISTORY
		1.0		Aug 2019	Gavin Townsend		Original Build
		
#>


Try{$Domain = $(get-addomain).dnsroot}
Catch{$Domain = ""}

$DeviceLog = "C:\Temp\Audit\$Domain O365 Device Compliance $(get-date -f yyyy-MM-dd).csv"
$Result =@()

[System.Collections.IDictionary]$script:schema = @{
    
    DeviceId = ''
    DeviceOSType = ''
    DeviceOSVersion = ''
    DeviceTrustLevel = ''
    DisplayName = ''
    IsCompliant = ''
    IsManaged = ''
    ApproximateLastLogonTimestamp = ''
    DeviceObjectId = ''    
    RegisteredOwnerUpn = ''
    RegisteredOwnerObjectId = ''
    RegisteredOwnerDisplayName = ''
}

function createResultObject
{

    [PSObject]$resultObject = New-Object -TypeName PSObject -Property $script:schema

    return $resultObject
}

    
[PSObject]$devices = get-msoldevice -all
foreach ($d in $devices)
{
	[PSObject]$deviceResult = createResultObject
	$deviceResult.DeviceId = $d.DeviceId 
	$deviceResult.DeviceOSType = $d.DeviceOSType 
	$deviceResult.DeviceOSVersion = $d.DeviceOSVersion 
	$deviceResult.DeviceTrustLevel = $d.DeviceTrustLevel
	$deviceResult.DisplayName = $d.DisplayName
	$deviceResult.IsCompliant = $d.GraphDeviceObject.IsCompliant
	$deviceResult.IsManaged = $d.GraphDeviceObject.IsManaged
	$deviceResult.DeviceObjectId = $d.ObjectId
	$deviceResult.RegisteredOwnerUpn = $d.RegisteredOwnerUpn
	$deviceResult.RegisteredOwnerDisplayName = $d.RegisteredOwnerDisplayName
	$deviceResult.ApproximateLastLogonTimestamp = $d.ApproximateLastLogonTimestamp

	$Result+=$deviceResult
}

$Result | Export-Csv -path $DeviceLog -NoTypeInformation -Encoding UTF8
