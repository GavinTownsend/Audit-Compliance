<#
	.SYNOPSIS
		Exports a basic list of Computer and User Objects
	
	.NOTES
		Script Name:	get-AD_UsersAndComputers.ps1
		Created By:		Gavin Townsend
		Date:			August 2019
		
	.DESCRIPTION
		The script performs the follow actions:
			- Exports a list of baisc User data from AD 
			- Exports a list of baisc Computer data from AD 
		
	.EXAMPLE
			.\get-AD_UsersAndComputers.ps1
			
	.REQUIREMENTS
		Active Directory module

	.AUDIT CRITERIA
		Complete a discovery scan of users and computers in AD
			
		Make a note of total numbers for comparison with other test cases
			
	.VERSION HISTORY
		1.0		Aug 2019	Gavin Townsend		Original Build
		
#>


Try{$Domain = $(get-addomain).dnsroot}
Catch{$Domain = ""}

$UserLog = "C:\Temp\Audit\$Domain User List $(get-date -f yyyy-MM-dd).csv"
$PCLog = "C:\Temp\Audit\$Domain Computer List $(get-date -f yyyy-MM-dd).csv"

$Users = Get-ADUser -Filter * -Properties * | Select-Object enabled,samaccountname,distinguishedName,mail,givenName,sn,@{label="Manager";expression={(Get-ADUser $_.Manager -Properties DisplayName).DisplayName}},physicalDeliveryOfficeName,Company,Department,Title,@{Name='Created';Expression={$_.Created.ToString("yyyy\/MM\/dd")}} 
$users | export-csv $UserLog -NoTypeInformation -Encoding UTF8
$uCount = $users.count

$Computers = Get-ADComputer -Filter * -Property * | Select-Object enabled,Name,Description,managedBy,OperatingSystem,OperatingSystemServicePack,OperatingSystemVersion,distinguishedName,whenCreated,LastLogonDate 
$Computers | export-csv $PCLog -NoTypeInformation -Encoding UTF8
$cCount = $Computers.count


write-Host ""
write-Host "---------------------------------------------------"
write-Host "Script Output Summary - Users and Computers $(Get-Date)"
write-Host ""
write-Host "User objects in $Domain : $uCount" 
write-Host "Computer objetcs in $Domain : $cCount"
write-Host ""
write-Host "---------------------------------------------------"
write-Host ""
Write-Host "User report completed. Details exported to $UserLog"
Write-Host "Computer report completed. Details exported to $PCLog"
