<#
	.SYNOPSIS
		Checks OS version to determine compliance for Microsoft Mainstream or Extended Support.
		
	.DESCRIPTION
		- Uses Active Directory plugin for PowerShell 
		- Collects Operating System and Version information for each server and computer
		- Identifies the Mainstream or Extended Support dates 
		
		- Compares current date with end of support dates to determine compliance
			* Compliant     = Now is earlier than the user defined Compliance Warning Date
			* Warning       = Now is earlier than the Microsoft End of Support Date (but later that the warning date)
			* Non-Compliant = Now is later than the Microsoft End of Support Date

	.EXAMPLE
		.\get-OSSupportCompliance.ps1

	.AUTHOR
		Gavin Townsend July 2019
		
	.NOTES	
		Server 2008     https://support.microsoft.com/en-au/help/4456235/end-of-support-for-windows-server-2008-and-windows-server-2008-r2
		Windows 10	https://support.microsoft.com/en-au/help/13853/windows-lifecycle-fact-sheet
		General		https://support.microsoft.com/en-au/lifecycle/search

#>


#Variables
$UseExtendedSupport = $TRUE   #Toggle TRUE/FALSE to measure compliance against Mainstream or Extended Support dates
$WarnDays = 365               #Warn if coming out of support within X days of End of Support Date

$Now = get-date
$OutData = @()
$Domain = $(get-addomain).dnsroot
$LogFile = "C:\Temp\OSCompliance $Domain $(get-date -f yyyy-MM-dd).csv"


#Query
$Computers = Get-ADComputer -Filter {Enabled -eq $True} -Property * | Select Name,OperatingSystem,OperatingSystemVersion,distinguishedName,LastLogonDate

foreach ($Computer in $Computers){

	#Properties
	$Name = $Computer.Name
	$DN = $Computer.distinguishedName
	$OS = $Computer.OperatingSystem
	$Version = $Computer.OperatingSystemVersion
	$LastLogon = $Computer.LastLogonDate

	#Servers
	if ($OS -like "*Server*") {
		$CountServers++
		$Type = "Server"
		$Build="N/A" 
	
		if ($OS -like "Windows Server 2000*") {
			$MainstreamSupport="June 6 2005"
			$ExtendedSupport="July 13 2010"
		}
		elseif ($OS -like "Windows Server 2003*") {
			$MainstreamSupport="July 13 2010"
			$ExtendedSupport="July 14 2015"
		}
		elseif ($OS -like "Windows Server 2008*") {
			$MainstreamSupport="April 9 2013"
			$ExtendedSupport="January 14 2020"
		}
		elseif ($OS -like "Windows Server 2012*") {
			$MainstreamSupport="October 9 2018"		
			$ExtendedSupport="October 10 2023"
		}
		elseif ($OS -like "Windows Server 2016*") {
			$MainstreamSupport="January 11 2022"		
			$ExtendedSupport="January 11 2027"
		}
		elseif ($OS -like "Windows Server 2019*") {
			$MainstreamSupport="TBA"		
			$ExtendedSupport="TBA"
		}
		else {
			$MainstreamSupport="Unknown"		
			$ExtendedSupport="Unknown"
		}
	}
	Else{
		$Type = "Computer"
		$CountComputers++
	
		#Legacy Computers
		if ($OS -like "Windows XP*") {
			$Build="N/A" 
			$MainstreamSupport="April 14 2009"
			$ExtendedSupport="April 8 2014"
		}
		elseif ($OS -like "Windows Vista*") {
			$Build="N/A" 
			$MainstreamSupport="April 10 2012"
			$ExtendedSupport="April 11 2017"
		}
		elseif ($OS -like "Windows 7*") {
			$Build="N/A" 
			$MainstreamSupport="January 13 2015"
			$ExtendedSupport="January 14 2020"
		}
		elseif ($OS -like "Windows 8*") {
			$Build="N/A"
			$MainstreamSupport="January 9 2018"		
			$ExtendedSupport="January 10 2023"
		}
		
		#Windows 10 Versions
		elseif ($OS -like "Windows 10*") {
			switch($Version){
				'10.0 (10240)'{
					$Build="1507"
					$MainstreamSupport="May 9 2017"		
					$ExtendedSupport="May 9 2017"
				}
				'10.0 (10586)'{
					$Build="1511"
					$MainstreamSupport="October 10 2017"		
					$ExtendedSupport="October 10 2017"
				}
				'10.0 (14393)'{
					$Build="1607"
					if ($Computer.OperatingSystem -like "*Enterprise*") {
						$MainstreamSupport="April 9 2019"		
						$ExtendedSupport="April 9 2019"
					}
					else{
						$MainstreamSupport="April 10 2018"		
						$ExtendedSupport="April 10 2018"
					}
				}
				'10.0 (15063)'{
					$Build="1703"
					if ($Computer.OperatingSystem -like "*Enterprise*") {
						$MainstreamSupport="October 8 2019"		
						$ExtendedSupport="October 8 2019"	
					}
					else{
						$MainstreamSupport="October 9 2018"		
						$ExtendedSupport="October 9 2018"	
					}	
				}
				'10.0 (16299)'{
					$Build="1709"
					if ($Computer.OperatingSystem -like "*Enterprise*") {
						$MainstreamSupport="April 14 2020"		
						$ExtendedSupport="April 14 2020"	
					}
					else{
						$MainstreamSupport="April 9 2019"		
						$ExtendedSupport="April 9 2019"	
					}	
				}
				
				'10.0 (17134)'{
					$Build="1803" 
					if ($Computer.OperatingSystem -like "*Enterprise*") {
						$MainstreamSupport="November 10 2020"		
						$ExtendedSupport="November 10 2020"	
					}
					else{
						$MainstreamSupport="November 12 2019"		
						$ExtendedSupport="November 12 2019"	
					}	
				}
				'10.0 (17763)'{
					$Build="1809"
					if ($Computer.OperatingSystem -like "*Enterprise*") {
						$MainstreamSupport="May 11 2021"		
						$ExtendedSupport="May 11 2021"	
					}
					else{
						$MainstreamSupport="May 12 2020"		
						$ExtendedSupport="May 12 2020"	
					}	
				}
				'10.0 (18362)'{
					$Build="1903"
					if ($Computer.OperatingSystem -like "*Enterprise*") {
						$MainstreamSupport="December 8 2022"		
						$ExtendedSupport="December 8 2022"
					}
					else{
						$MainstreamSupport="December 8 2022"		
						$ExtendedSupport="December 8 2022"	
					}
				}
				'10.0 (18922)'{
					$Build="TBA"
					if ($Computer.OperatingSystem -like "*Enterprise*") {
						$MainstreamSupport="TBA"		
						$ExtendedSupport="TBA"
					}
					else{
						$MainstreamSupport="TBA"		
						$ExtendedSupport="TBA"
					}
				}
				default {
					$Build="Unknown" 
					$MainstreamSupport="Unknown"
					$ExtendedSupport="Unknown"
				}
			}
		}
	}

	#Verify Compliance
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
		$SupportDate = [datetime]::parseexact($Support, 'MMMM d yyyy', $null)
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
	
	#Add Data to Array
	$obj = New-Object PSobject
	$obj | Add-Member NoteProperty -Name "Type" -Value $Type
	$obj | Add-Member NoteProperty -Name "Name" -Value $Computer.Name
	$obj | Add-Member NoteProperty -Name "DN" -Value $Computer.distinguishedName
	$obj | Add-Member NoteProperty -Name "Last Logon" -Value $LastLogon
	$obj | Add-Member NoteProperty -Name "Operating System" -Value $Computer.OperatingSystem
	$obj | Add-Member NoteProperty -Name "Version" -Value $Version
	$obj | Add-Member NoteProperty -Name "Build" -Value $Build
	$obj | Add-Member NoteProperty -Name "Support" -Value $Support
	$obj | Add-Member NoteProperty -Name "Compliant" -Value $Compliant

	$OutData += $obj
}

#Count
Write-Host "There are $CountServers servers and $CountComputers computers in the $Domain domain."
write-host "Compliant: $CountYes"
write-host "Warning: $CountWarn"
write-host "Non-Compliant: $CountNo"
write-host "Unknown or TBA: $CountUnknown"
write-host ""
Write-Host "Full details have been exported to $LogFile"

#Export
$OutData = $OutData | sort -Property "Type","Name"
$OutData | Export-CSV $LogFile -notype
