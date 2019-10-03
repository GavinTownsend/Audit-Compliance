<#
	.SYNOPSIS
		
		Lists the MFA enrolment status of all O365 users with an Administrator role
	
	.NOTES
		Script Name:	get-O365_AdminMFAStatus.ps1
		Created By:		Gavin Townsend
		Date:			August 2019
	
	.DESCRIPTION
		
		Gathers a list of Users enrolled in Office 365
		
		Checks whether they have MFA enabled (strong authentication)
		
		Checks whether account is active (through mailbox last logon)

			
	.EXAMPLE
		
		.\Get-O365_AdminMFAStatus.ps1
		
		#Connect as a Non MFA enabled user
			$AdminCred = Get-Credential admin@example.com
			Connect-MsolService -Credential $AdminCred

		#Connect as an MFA enabled user (login GUI)
			Connect-MsolService
		
	.REQUIREMENTS
		O365 PowerShell plugins https://docs.microsoft.com/en-us/office365/enterprise/powershell/connect-to-office-365-powershell
		
		NB. Only returns values where O365 is the Identity Provider (IDp). Does not return values for 3rd parties (eg ADFS, Okta etc)
		
	.AUDIT CRITERIA
		Complete a discovery scan of O365 Administrators
		
		Make a note of the following exceptions
			- Where administrators do not have MFA enabled
	
	.VERSION HISTORY
	
		- v1.0	June 2017	Original Script		Gavin Townsend
		- v2.0	Aug 2019	Added extra fields	Gavin Townsend

#>


Function Get-O365AdminMFAStatus{
	$AdminData=@()
	$objRole=@()
	$Domain = $(get-addomain).dnsroot
	$Log = "C:\temp\Audit\$Domain O365 Admin MFA Status $(get-date -f yyyy-MM-dd).csv"
	
	try{
		$Roles = Get-MsolRole | where {$_.name -LIKE "*Administrator*"}
		$Roles = ($Roles).name
		
		foreach ($Role in $Roles){
			$Members = Get-MsolRoleMember -RoleObjectId (Get-MsolRole -RoleName $Role).ObjectId 
			foreach ($Member in $Members){
				$MsUser = $Member | Get-MsolUser
				if($MsUser.StrongAuthenticationMethods.Count -eq 0) {
					$Enabled = "False"
					write-host $Role - $Member.DisplayName "No MFA enabled" -foregroundcolor red
				}
				Else{
					$Enabled = "True"
					write-host $Role - $Member.DisplayName "MFA enabled" -foregroundcolor green
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
				$objRole | Add-Member -MemberType NoteProperty -Name "Role Name" -Value $Role
				$objRole | Add-Member -MemberType NoteProperty -Name "Display Name" -Value $Member.DisplayName
				$objRole | Add-Member -MemberType NoteProperty -Name "UPN" -Value $Member.UserPrincipalName
				$objRole | Add-Member -MemberType NoteProperty -Name "Licensed" -Value $Member.IsLicensed
				$objRole | Add-Member -MemberType NoteProperty -Name "Last Logon" -Value $LastLogon
				$objRole | Add-Member -MemberType NoteProperty -Name "MFA Enabled?" -Value $Enabled
				
				$AdminData += $objRole
			}
		}
		
		$AdminData | Export-Csv -NoTypeInformation $Log 
		write-host ""
		write-host "CSV Export Complete to $Log" -foregroundcolor yellow
	}
	Catch{
		Write-host "There was an error: $($_.Exception.Message)"
	}
}

Get-O365AdminMFAStatus
