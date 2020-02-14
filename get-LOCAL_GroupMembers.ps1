<#
	.SYNOPSIS
		Checks local group membership on selected computers
	
	.NOTES
		Script Name:	get-LOCAL_GroupMembers.ps1
		Created By:		Gavin Townsend
		Date:			August 2019
		
	.DESCRIPTION
		The script performs the follow actions:
			- Makes a selection of computer objects (eg all Servers, selection of 100 computers)
			- Enumerates the members for important local groups (administrators, power users etc)
			- Checks if there are any disabled or deleted accounts
			- Exports list for review
			
		
	.EXAMPLE
			.\get-LOCAL_GroupMembers.ps1
			
			Update selection of $Computers as required
			
	.REQUIREMENTS
		Active Directory module
		WinRM enabled on target machines (for WMI)
		Local administrator on target machines
		
		NB. Some WMI scans do not work on all operating systems (particularly older ones)
		
		
		O365 PowerShell plugins https://docs.microsoft.com/en-us/office365/enterprise/powershell/connect-to-office-365-powershell
		
			Install-Module MSOnline
		
		#Connect as a Non MFA enabled user
			$AdminCred = Get-Credential admin@example.com
			Connect-MsolService -Credential $AdminCred

		#Connect as an MFA enabled user (login GUI)
			Connect-MsolService
			
		
	.AUDIT CRITERIA
		Complete a discovery scan of local group members
		
		Collect a good sized random sample from both Servers and Computers (ensure to rename output file, to avoid overwriting)
			
		Make a note of the following exceptions
			- Where Domain user accounts are members of privileged groups (eg Administrators)
		
	.VERSION HISTORY
		1.0		Aug 2019	Gavin Townsend		Original Build
		
#>
Try{$Domain = $(get-addomain).dnsroot}
Catch{$Domain = ""}

$Log = "C:\temp\Audit\$Domain Local Groups $(get-date -f yyyy-MM-dd).csv"

try{
    $Recent = (Get-Date).AddDays(-1)
    $Computers = Get-ADComputer -Filter {OperatingSystem -NOTLIKE "*server*" -AND Enabled -eq $TRUE -AND lastlogondate -gt $Recent } -Property Name
	#$Computers = Get-ADComputer -Filter {OperatingSystem -LIKE "*server*" -AND Enabled -eq $TRUE -AND lastlogondate -gt $Recent } -Property Name
    $Auth= "AD"
}
Catch{
    $Computers = Get-MsolDevice -All |? {$_.Enabled -eq $True -and $_.DeviceOsType -eq "Windows"} | Select DisplayName
    $Auth="Azure"
}

$MachinesToScanCount = 100
$Computers = Get-Random -InputObject $Computers -Count $MachinesToScanCount

$LocalGroups =@("Administrators","Remote Desktop Users","Power Users","Backup Operators")
$GroupData =@()

$BadADLogins = 0
$ADEnabled = 0
$AzureEnabled = 0
$OnCount = 0

foreach ($Computer in $Computers) {
    if ($Auth -eq "AD"){
        $Computer = $Computer.name
    }
    else{
       $Computer = $Computer.DisplayName
    }

	if(!(Test-Connection -Cn $Computer -BufferSize 16 -Count 1 -ea 0 -quiet)){
		write-host "WARNING: $Computer not accessible" -f yellow
	}
	else {
		try {
			$Computer = $Computer
			$OnCount++
			write-host "Working on $computer"
			foreach ($Group in $LocalGroups) {
						
				([adsi]"WinNT://$Computer/$Group,group").psbase.Invoke('Members') | ForEach-Object {
					$Member = $_.GetType().InvokeMember('Name', 'GetProperty', $null, $_, $null)
				
					#Check Account Type and AD/Azure
					if (($Member -eq "administrator") -or ($Member -eq "INTERACTIVE")){
						$LoginEnabled = "Common Local Account"
					}
					elseif (($Member -eq "Authenticated Users") -or ($Member -eq "Domain Users") -or ($Member -eq "Administrators") -or ($Member -eq "Backup Operators")){
						$LoginEnabled = "Common Built in Group"
					}
					elseif ($Member -LIKE "S-1-5*"){
						$LoginEnabled = "Deleted Account"
						$BadADLogins++
					}
					else{
						Try{
							if ($Auth -eq "AD"){
								$ADUser = get-aduser $Member -properties enabled
								$LoginEnabled = $ADUser.enabled
								$ADEnabled++
							}
							elseif ($Auth -eq "Azure"){
								$AzureUser = get-msoluser -SearchString $Member -properties isLicensed
								$LoginEnabled = $AzureUser.isLicensed
								$AzureEnabled++
							}
						}
						catch{
							$LoginEnabled = "Local Account"
						}
					}
								
					#List Groups and Members
					$GRPobj = New-Object PSobject
					$GRPobj | Add-Member -MemberType NoteProperty -name "Computer" -value $Computer
					$GRPobj | Add-Member -MemberType NoteProperty -name "Group" -value $Group
					$GRPobj | Add-Member -MemberType NoteProperty -name "Member" -value $Member
					$GRPobj | Add-Member -MemberType NoteProperty -name "AD Enabled" -value $LoginEnabled
					$GroupData += $GRPobj
				}			
			}
		}
		catch {
			Write-Warning $_
		}
	}
}
$GroupData = $GroupData | sort -Property "Server","Group","Member"
$GroupData | Export-Csv $Log -notype -Encoding UTF8
write-host ""
write-host "CSV Export Complete to $Log"
Write-Host "Bad AD Logins: $BadADLogins" -foregroundcolor yellow

Try{$Ratio = $OnCount/$MachinesToScanCount}
Catch{$Ratio = "Unable to calculate"}

write-Host ""
write-Host "--------------------------------------------------------"
write-Host "Script Output Summary - Local Group Scan $(Get-Date)"
write-Host ""
write-Host "Total Machines to Check: $MachinesToScanCount"
write-Host "Machines Online Count: $OnCount"
if ($Ratio -gt 0.5) {
	write-host "Good sample of machines tested" -foregroundcolor green
}
else{
	write-host "Poor sample of machines tested." -foregroundcolor yellow
	write-host "Please ensure WinRM is enabled and you have local admin access to target endpoints." -foregroundcolor yellow
}
write-Host ""
if ($Auth -eq "AD"){
	Write-Host "Individual AD users accounts found in local Groups: $ADEnabled" -foregroundcolor red
}
elseif ($Auth -eq "Azure"){
	Write-Host "Individual Azure user accounts found in local Groups: $AzureEnabled" -foregroundcolor red
}
Write-Host "Bad AD Logins: $BadADLogins" -foregroundcolor yellow
write-host ""
write-Host "--------------------------------------------------------"
write-host "Local Group scanning complete. Log Export to $Log" 

