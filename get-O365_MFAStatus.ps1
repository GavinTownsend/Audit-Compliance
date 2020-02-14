<#
	.SYNOPSIS
		
		Lists the MFA enrolment status of all O365 users
	
	.NOTES
		Script Name:	get-O365_MFAStatus.ps1
		Created By:		Gavin Townsend
		Date:			August 2019
	
	.DESCRIPTION
		
		Gathers a list of Users enrolled in Office 365
		
		Checks whether they have MFA enabled (strong authentication)
		
		Checks whether account is recently active (through mailbox last logon)

			
	.EXAMPLE
		
		.\Get-O365_MFAStatus.ps1
		
		#Connect as a Non MFA enabled user
			$AdminCred = Get-Credential admin@example.com
			Connect-MsolService -Credential $AdminCred

		#Connect as an MFA enabled user (login GUI)
			Connect-MsolService
		
	.REQUIREMENTS
		O365 PowerShell plugins https://docs.microsoft.com/en-us/office365/enterprise/powershell/connect-to-office-365-powershell
		
			Install-Module MSOnline
		
		NB. Only returns values where O365 is the Identity Provider (IDp). Does not return values for 3rd parties (eg ADFS, Okta etc)
		
		Global administrator role
		
	.AUDIT CRITERIA
		Complete a discovery scan of O365 Users
		
		Make a note of the following exceptions
			- Where users do not have MFA enabled
	
	.VERSION HISTORY
	
		- v1.0	June 2017	Original Script		Gavin Townsend
		- v2.0	Aug	2019	Added extra fields	Gavin Townsend

#>


Function Get-O365MFAStatus{
	$UserData=@()
	$objRole=@()
	Try{$Domain = $(get-addomain).dnsroot}
	Catch{$Domain = ""}
	
	$UserCount = 0
	$EnabledCount = 0
	$NotCount = 0

	$Log = "C:\temp\Audit\$Domain O365 User MFA Status $(get-date -f yyyy-MM-dd).csv"
	$MFAProvider = Read-Host "Enter the Name of the MFA IDp for Users (eg Azure Cloud, Azure On-Premises, Okta, RSA, None)"
	
	try{
		$MsUsers = Get-MsolUser -EnabledFilter EnabledOnly -MaxResults 20000
		foreach ($MsUser in $MsUsers){
			$UserCount++
			
			if($MsUser.StrongAuthenticationMethods.Count -eq 0) {
				$Enabled = "False"
				write-host $MsUser.DisplayName "No MFA enabled" -foregroundcolor red
				$NotCount++
			}
			Else{
				$Enabled = "True"
				write-host $MsUser.DisplayName "MFA enabled" -foregroundcolor green
				$EnabledCount++
			}	
		
			Try{
				$Exist = [bool](Get-mailbox $MsUser.UserPrincipalName -erroraction SilentlyContinue)
				if ($Exist){
					$MBStats = Get-MailboxStatistics $MsUser.UserPrincipalName
					$LastLogon = $MBstats.LastLogonTime
				}
				Else{
					$LastLogon = "N/A"
				}	
			}
			Catch{
				$LastLogon = "N/A"
			}
		
			$objRole = New-Object -TypeName PSObject
			$objRole | Add-Member -MemberType NoteProperty -Name "Display Name" -Value $MsUser.DisplayName
			$objRole | Add-Member -MemberType NoteProperty -Name "UPN" -Value $MsUser.UserPrincipalName
			$objRole | Add-Member -MemberType NoteProperty -Name "Licensed" -Value $MsUser.IsLicensed
			$objRole | Add-Member -MemberType NoteProperty -Name "Last Logon" -Value $LastLogon
			$objRole | Add-Member -MemberType NoteProperty -Name "MFA Enabled?" -Value $Enabled
			
			$UserData += $objRole
		}
		
		$UserData | Export-Csv -NoTypeInformation $Log -Encoding UTF8
		
		write-Host ""
		write-Host "--------------------------------------------------------"
		write-Host "Script Output Summary - O365 User MFA Compliance $(Get-Date)"
		write-Host ""
		Write-Host "There are $UserCount O365 Users in the $Domain domain."
		write-Host ""
		Write-Host "The MFA provider has been reported as $MFAProvider"
		write-host ""
		write-host "MFA Enabled Count: $EnabledCount" -foregroundcolor green
		write-host "MFA NOT Enabled Count: $NotCount" -foregroundcolor red
		write-host ""
		write-Host "--------------------------------------------------------"
		write-host "MFA Scan Complete. CSV Export Complete to $Log"
	}
	Catch{
		Write-host "There was an error: $($_.Exception.Message)"
	}
}

Get-O365MFAStatus
