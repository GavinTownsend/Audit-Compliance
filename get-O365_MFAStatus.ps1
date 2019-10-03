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
		
		NB. Only returns values where O365 is the Identity Provider (IDp). Does not return values for 3rd parties (eg ADFS, Okta etc)
		
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
	$Domain = $(get-addomain).dnsroot
	$Log = "C:\temp\Audit\$Domain O365 User MFA Status $(get-date -f yyyy-MM-dd).csv"
	
	try{
		$MsUsers = Get-MsolUser -EnabledFilter EnabledOnly -MaxResults 10000
		foreach ($MsUser in $MsUsers){
			if($MsUser.StrongAuthenticationMethods.Count -eq 0) {
				$Enabled = "False"
				write-host $MsUser.DisplayName "No MFA enabled" -foregroundcolor red
			}
			Else{
				$Enabled = "True"
				write-host $MsUser.DisplayName "MFA enabled" -foregroundcolor green
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
		
		$UserData | Export-Csv -NoTypeInformation $Log	
		write-host ""
		write-host "CSV Export Complete to $Log" -foregroundcolor yellow
	}
	Catch{
		Write-host "There was an error: $($_.Exception.Message)"
	}
}

Get-O365MFAStatus
