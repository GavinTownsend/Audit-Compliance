
<#
	.SYNOPSIS
		Checks OS version to determine compliance for Microsoft Mainstream or Extended Support.
	
	.NOTES
		Script Name:	get-O365_OSCompliance.ps1
		Created By:		Gavin Townsend
		Date:			October 2019
	
	.DESCRIPTION
		- Collects Operating System and Version information for each server and computer
		- Identifies the Mainstream or Extended Support dates 
		
		- Compares current date with end of support dates to determine compliance
				* Compliant		= Now is earlier than the user defined Compliance Warning Date
				* Warning		= Now is earlier than the Microsoft End of Support Date (but later that the warning date)
				* Non-Compliant = Now is later than the Microsoft End of Support Date

	.AUDIT CRITERIA
		Complete a discovery scan of operating systems in Azure AD
			
		Note any machines where Compliant = 'Warning' or 'No' in the CSV report
				
	.EXAMPLE
		.\get-o365_OSCompliance.ps1
		
	.REQUIREMENTS
		O365 PowerShell plugins https://docs.microsoft.com/en-us/office365/enterprise/powershell/connect-to-office-365-powershell
		
			Install-Module MSOnline
		
		#Connect as a Non MFA enabled user
			$AdminCred = Get-Credential admin@example.com
			Connect-MsolService -Credential $AdminCred

		#Connect as an MFA enabled user (login GUI)
			Connect-MsolService
		
		Global administrator role
		
	.VERSION HISTORY
		1.0		Oct 2019	Gavin Townsend		Original Build
		
	.INFO	
		Windows 10	https://support.microsoft.com/en-au/help/13853/windows-lifecycle-fact-sheet
		General		https://support.microsoft.com/en-au/lifecycle/search

#>


#Variables
$UseExtendedSupport = $TRUE	  #Toggle TRUE/FALSE to measure compliance against Mainstream or Extended Support dates
$WarnDays = 365				  #Warn if coming out of support within X days of End of Support Date

$Now = get-date
$OutData = @()
Try{$Domain = $(get-addomain).dnsroot}
Catch{$Domain = ""}

$Log = "C:\Temp\Audit\$Domain O365 OS Compliance $(get-date -f yyyy-MM-dd).csv"


#Query
$Devices = Get-MsolDevice -All |? {$_.Enabled -eq $True} | Select Enabled,DisplayName,DeviceOsType,DeviceOsVersion,ApproximateLastLogonTimestamp
$Edition = Read-Host 'Enter machine edition type (ie Enterprise or Professional)'
$Edition.ToLower()

foreach ($Device in $Devices){

	#Properties
	$Enabled = $Device.Enabled
	$Name = $Device.DisplayName
	$OS = $Device.DeviceOsType
	$Version = $Device.DeviceOsVersion
	$LastLogon = $Device.ApproximateLastLogonTimestamp
	$Type = "Computer"

	#Windows 10 Versions
	if ($OS -like "Windows") {
		$CountComputers++
	
		switch -wildcard ($Version){
			'10.0.10240*'{
				$Build="1507"
				$MainstreamSupport="May 9 2017"		
				$ExtendedSupport="May 9 2017"
			}
			'10.0.10586*'{
				$Build="1511"
				$MainstreamSupport="October 10 2017"		
				$ExtendedSupport="October 10 2017"
			}
			'10.0.14393*'{
				$Build="1607"
				if ($Edition -eq "enterprise") {
					$MainstreamSupport="April 9 2019"		
					$ExtendedSupport="April 9 2019"
				}
				else{
					$MainstreamSupport="April 10 2018"		
					$ExtendedSupport="April 10 2018"
				}
			}
			'10.0.15063*'{
				$Build="1703"
				if ($Edition -eq "enterprise") {
					$MainstreamSupport="October 8 2019"		
					$ExtendedSupport="October 8 2019"	
				}
				else{
					$MainstreamSupport="October 9 2018"		
					$ExtendedSupport="October 9 2018"	
				}	
			}
			'10.0.16299*'{
				$Build="1709"
				if ($Edition -eq "enterprise") {
					$MainstreamSupport="October 13 2020"		
					$ExtendedSupport="October 13 2020"	
				}
				else{
					$MainstreamSupport="April 9 2019"		
					$ExtendedSupport="April 9 2019"	
				}	
			}
			
			'10.0.17134*'{
				$Build="1803" 
				if ($Edition -eq "enterprise") {
					$MainstreamSupport="November 10 2020"		
					$ExtendedSupport="November 10 2020"	
				}
				else{
					$MainstreamSupport="November 12 2019"		
					$ExtendedSupport="November 12 2019"	
				}	
			}
			'10.0.17763*'{
				$Build="1809"
				if ($Edition -eq "enterprise") {
					$MainstreamSupport="May 11 2021"		
					$ExtendedSupport="May 11 2021"	
				}
				else{
					$MainstreamSupport="November 10 2020"		
					$ExtendedSupport="November 10 2020"	
				}	
			}
			'10.0.18362*'{
				$Build="1903"
				if ($Edition -eq "enterprise") {
					$MainstreamSupport="December 8 2021"		
					$ExtendedSupport="December 8 2021"
				}
				else{
					$MainstreamSupport="December 8 2021"		
					$ExtendedSupport="December 8 2021"	
				}
			}
			'10.0.18363*'{
				$Build="1909"
				if ($Edition -eq "enterprise") {
					$MainstreamSupport="May 10 2022"		
					$ExtendedSupport="May 10 2022"
				}
				else{
					$MainstreamSupport="May 11 2021"		
					$ExtendedSupport="May 11 2021"
				}
			}
			default {
				$Build="Unknown" 
				$MainstreamSupport="Unknown"
				$ExtendedSupport="Unknown"
			}
		}
	}

	#Verify Compliance
	Try{
		If ($UseExtendedSupport -eq $TRUE){
			$Support = $ExtendedSupport
		}
		else{
			$Support = $MainstreamSupport
		}
		
		if ($Support -eq "Unknown" -OR $Support -eq "N/A" -OR $Support -eq "TBA"){
			$Compliant = $Support
			$CountUnknown++
		}
		else{
			#$SupportDate = [datetime]::parseexact($Support, 'MMMM d yyyy', $null)
			$SupportDate = [datetime]::parseexact($Support, 'MMMM d yyyy', [System.Globalization.DateTimeFormatInfo]::InvariantInfo,[System.Globalization.DateTimeStyles]::None)
			$WarnDate = ($SupportDate).AddDays(-$WarnDays)
		
			if ($Now -le $WarnDate){
				$Compliant="Yes"
				$CountYes++
			}
			elseif ($Now -le $SupportDate){
				$Compliant="Warning"
				$CountWarn++
			}
			else{
				$Compliant="No"
				$CountNo++
			}
		}
	}
	Catch{
		$Compliant="Unknown"
	}
	
	#Add Data to Array
	$obj = New-Object PSobject
	$obj | Add-Member NoteProperty -Name "Type" -Value $Type
	$obj | Add-Member NoteProperty -Name "Enabled" -Value $Enabled
	$obj | Add-Member NoteProperty -Name "Name" -Value $Name
	$obj | Add-Member NoteProperty -Name "Last Logon" -Value $LastLogon
	$obj | Add-Member NoteProperty -Name "Operating System" -Value $OS
	$obj | Add-Member NoteProperty -Name "Version" -Value $Version
	$obj | Add-Member NoteProperty -Name "Build" -Value $Build
	$obj | Add-Member NoteProperty -Name "Support" -Value $Support
	$obj | Add-Member NoteProperty -Name "Compliant" -Value $Compliant

	$OutData += $obj
}

#Count

write-Host ""
write-Host "--------------------------------------------------------"
write-Host "Script Output Summary - O365 OS Compliance $(Get-Date)"
write-Host ""
Write-Host "There are $CountComputers computers in the $Domain domain."
write-host ""
write-host "Compliant: $CountYes" -foregroundcolor green
write-host "Warning: $CountWarn" -foregroundcolor yellow
write-host "Non-Compliant: $CountNo" -foregroundcolor red
write-host "Unknown or TBA: $CountUnknown"
write-host ""
write-Host "--------------------------------------------------------"


#Export
$OutData = $OutData | sort -Property "Type","Name"
$OutData | Export-CSV $Log -notype -Encoding UTF8
write-host "Log Export Complete to $Log" -foregroundcolor yellow
