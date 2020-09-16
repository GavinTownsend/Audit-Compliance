
<#
	.SYNOPSIS
		Checks OS version to determine compliance for Microsoft Mainstream or Extended Support.
	
	.NOTES
		Script Name:	get-AD_OSCompliance.ps1
		Created By:		Gavin Townsend
		Date:			August 2019
	
	.DESCRIPTION
		- Collects Operating System and Version information for each server and computer
		- Identifies the Mainstream or Extended Support dates 
		
		- Compares current date with end of support dates to determine compliance
				* Compliant		= Now is earlier than the user defined Compliance Warning Date
				* Warning		= Now is earlier than the Microsoft End of Support Date (but later that the warning date)
				* Non-Compliant = Now is later than the Microsoft End of Support Date

	.AUDIT CRITERIA
		Complete a discovery scan of operating systems in AD
			
		Note any machines where Compliant = 'Warning' or 'No' in the CSV report
				
	.EXAMPLE
		.\get-AD_OSCompliance.ps1

	.REQUIREMENTS
		Active Directory module
		
	.VERSION HISTORY
		1.0		June 2019	Gavin Townsend		Original Build
		2.0		Sept 2020	Gavin Townsend		Changes to end of service dates
		
	.INFO	
		Server 2008 https://support.microsoft.com/en-au/help/4456235/end-of-support-for-windows-server-2008-and-windows-server-2008-r2
		Windows 10	https://support.microsoft.com/en-au/help/13853/windows-lifecycle-fact-sheet
		Win10 LTSB 	https://docs.microsoft.com/en-us/windows/release-information/
		General		https://support.microsoft.com/en-au/lifecycle/search

#>


#Variables
$UseExtendedSupport = $TRUE	  #Toggle TRUE/FALSE to measure compliance against Mainstream or Extended Support dates
$WarnDays = 365				  #Warn if coming out of support within X days of End of Support Date

$Now = get-date
$OutData = @()
Try{$Domain = $(get-addomain).dnsroot}
Catch{$Domain = ""}

$Log = "C:\Temp\Audit\$Domain OS Compliance $(get-date -f yyyy-MM-dd).csv"


#Query
$Computers = Get-ADComputer -Filter {Enabled -eq $True} -Property * | Select Enabled,Name,OperatingSystem,OperatingSystemVersion,distinguishedName,LastLogonDate

foreach ($Computer in $Computers){

	#Properties
	$Enabled = $Computer.Enabled
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
			$MainstreamSupport="January 9 2024"		
			$ExtendedSupport="January 9 2029"
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
					if ($Computer.OperatingSystem -like "*LTSB*") {
						$MainstreamSupport="October 10 2021"		
						$ExtendedSupport="October 13 2026"
					}
					elseif ($Computer.OperatingSystem -like "*Enterprise*") {
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
						$MainstreamSupport="October 13 2020"		
						$ExtendedSupport="October 13 2020"	
					}
					else{
						$MainstreamSupport="April 9 2019"		
						$ExtendedSupport="April 9 2019"	
					}	
				}
				
				'10.0 (17134)'{
					$Build="1803" 
					if ($Computer.OperatingSystem -like "*Enterprise*") {
						$MainstreamSupport="May 11 2021"		
						$ExtendedSupport="May 11 2021"	
					}
					else{
						$MainstreamSupport="November 12 2019"		
						$ExtendedSupport="November 12 2019"	
					}	
				}
				'10.0 (17763)'{
					$Build="1809"
					if ($Computer.OperatingSystem -like "*LTSC*") {
						$MainstreamSupport="January 9 2024"		
						$ExtendedSupport="January 9 2029"
					}
					elseif ($Computer.OperatingSystem -like "*Enterprise*") {
						$MainstreamSupport="May 11 2021"		
						$ExtendedSupport="May 11 2021"	
					}
					else{
						$MainstreamSupport="November 10 2020"		
						$ExtendedSupport="November 10 2020"	
					}	
				}
				'10.0 (18362)'{
					$Build="1903"
					if ($Computer.OperatingSystem -like "*Enterprise*") {
						$MainstreamSupport="December 8 2020"		
						$ExtendedSupport="December 8 2020"
					}
					else{
						$MainstreamSupport="December 8 2020"		
						$ExtendedSupport="December 8 2020"	
					}
				}
				'10.0 (18363)'{
					$Build="1909"
					if ($Computer.OperatingSystem -like "*Enterprise*") {
						$MainstreamSupport="May 10 2022"		
						$ExtendedSupport="May 10 2022"
					}
					else{
						$MainstreamSupport="May 11 2021"		
						$ExtendedSupport="May 11 2021"	
					}
				}
				'10.0 (19041)'{
					$Build="2004"
					if ($Computer.OperatingSystem -like "*Enterprise*") {
						$MainstreamSupport="December 14 2021"		
						$ExtendedSupport="December 14 2021"
					}
					else{
						$MainstreamSupport="December 14 2021"		
						$ExtendedSupport="December 14 2021"
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
	
	#Add Data to Array
	$obj = New-Object PSobject
	$obj | Add-Member NoteProperty -Name "Type" -Value $Type
	$obj | Add-Member NoteProperty -Name "Enabled" -Value $Enabled
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
write-Host ""
write-Host "--------------------------------------------------------"
write-Host "Script Output Summary - OS Compliance $(Get-Date)"
write-Host ""
Write-Host "There are $CountServers servers and $CountComputers computers in the $Domain domain."
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
write-host "Log Export Complete to $Log"

# SIG # Begin signature block
# MIITugYJKoZIhvcNAQcCoIITqzCCE6cCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU1s5vTswbS4mdhk+GjP8DLvB0
# 5t2gghDxMIIFbzCCBFegAwIBAgIRANP4/upFzWc5gWkrbWGAMjcwDQYJKoZIhvcN
# AQELBQAwfDELMAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3Rl
# cjEQMA4GA1UEBxMHU2FsZm9yZDEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSQw
# IgYDVQQDExtTZWN0aWdvIFJTQSBDb2RlIFNpZ25pbmcgQ0EwHhcNMjAwODA1MDAw
# MDAwWhcNMjEwODA1MjM1OTU5WjCBrzELMAkGA1UEBhMCR0IxETAPBgNVBBEMCEVD
# M00gM0JZMQ8wDQYDVQQHDAZMb25kb24xJjAkBgNVBAkMHTIwIEZlbmNodXJjaCBT
# dHJlZXQsIExldmVsIDI1MSkwJwYDVQQKDCBHcmFudCBUaG9ybnRvbiBJbnRlcm5h
# dGlvbmFsIEx0ZDEpMCcGA1UEAwwgR3JhbnQgVGhvcm50b24gSW50ZXJuYXRpb25h
# bCBMdGQwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDWYKLS6uRLWcxV
# +zqTN7u17c4yzWT4rCVr7O8phqjubVKNrTtUpVNqj/gmToB1AnXv+x7GSVwwvCWw
# atImqrcMSPQJVwFSug7j7qRTyauyNQzMjHs5oxLicLGVR4mQjLIReYX93yn8Df4K
# VqRI0WkatwEpPa8W0D5sUiCKUlBLgjO0gBxnM/d8CLkB2xkjpU5F4+gHJVSGUewC
# 6gfXnndnQWwIVUZhAvZG4Su45cuCWIa7mLEurWpc59z4KpbZDW50hIyWKbTUFY1u
# RPnozAoSf3s4QLCVQ8C/dYFCMcXhX6O1y78reYnaKuXF1vtag8A0Z8xMm4yKNFV7
# OcxYq/gtAgMBAAGjggG2MIIBsjAfBgNVHSMEGDAWgBQO4TqoUzox1Yq+wbutZxoD
# ha00DjAdBgNVHQ4EFgQUR16h+rCW+9892U4nFJvQipePF1gwDgYDVR0PAQH/BAQD
# AgeAMAwGA1UdEwEB/wQCMAAwEwYDVR0lBAwwCgYIKwYBBQUHAwMwEQYJYIZIAYb4
# QgEBBAQDAgQQMEoGA1UdIARDMEEwNQYMKwYBBAGyMQECAQMCMCUwIwYIKwYBBQUH
# AgEWF2h0dHBzOi8vc2VjdGlnby5jb20vQ1BTMAgGBmeBDAEEATBDBgNVHR8EPDA6
# MDigNqA0hjJodHRwOi8vY3JsLnNlY3RpZ28uY29tL1NlY3RpZ29SU0FDb2RlU2ln
# bmluZ0NBLmNybDBzBggrBgEFBQcBAQRnMGUwPgYIKwYBBQUHMAKGMmh0dHA6Ly9j
# cnQuc2VjdGlnby5jb20vU2VjdGlnb1JTQUNvZGVTaWduaW5nQ0EuY3J0MCMGCCsG
# AQUFBzABhhdodHRwOi8vb2NzcC5zZWN0aWdvLmNvbTAkBgNVHREEHTAbgRlnYXZp
# bi50b3duc2VuZEBndGkuZ3QuY29tMA0GCSqGSIb3DQEBCwUAA4IBAQBb5r7Bvf7t
# HlGFCjNPpmLm9N4sFpTeHg5W4mmIUSwjcbUQs7NUzllBSLqBHg3BxOOO4yKkpkUF
# ujeRUFVHWLU4dtqSntA4WYcU9B4wioWD+/0c6hUgACGpkDxvdzT2joXReuP0uTI+
# U4fzYZYiX8J4CvUTufxhKwNxMf+aPYZSf731z3J/BlNEpUCv/C6WsSSpCYGxTM+e
# JFEkfsnCoO+/gOVyr+7p4xHRBwDn7xIBQjLDyd3ZkuQShjKRyTBrRMj/OyXu1xhM
# X2tazJ2IHJcY7FxL+L3rg5rYxnoTI33UsRHlk6/ULWosgFtlUcEjeXVL3Vu2PIR6
# uSxF7EcpEFvEMIIFgTCCBGmgAwIBAgIQOXJEOvkit1HX02wQ3TE1lTANBgkqhkiG
# 9w0BAQwFADB7MQswCQYDVQQGEwJHQjEbMBkGA1UECAwSR3JlYXRlciBNYW5jaGVz
# dGVyMRAwDgYDVQQHDAdTYWxmb3JkMRowGAYDVQQKDBFDb21vZG8gQ0EgTGltaXRl
# ZDEhMB8GA1UEAwwYQUFBIENlcnRpZmljYXRlIFNlcnZpY2VzMB4XDTE5MDMxMjAw
# MDAwMFoXDTI4MTIzMTIzNTk1OVowgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpO
# ZXcgSmVyc2V5MRQwEgYDVQQHEwtKZXJzZXkgQ2l0eTEeMBwGA1UEChMVVGhlIFVT
# RVJUUlVTVCBOZXR3b3JrMS4wLAYDVQQDEyVVU0VSVHJ1c3QgUlNBIENlcnRpZmlj
# YXRpb24gQXV0aG9yaXR5MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA
# gBJlFzYOw9sIs9CsVw127c0n00ytUINh4qogTQktZAnczomfzD2p7PbPwdzx07HW
# ezcoEStH2jnGvDoZtF+mvX2do2NCtnbyqTsrkfjib9DsFiCQCT7i6HTJGLSR1GJk
# 23+jBvGIGGqQIjy8/hPwhxR79uQfjtTkUcYRZ0YIUcuGFFQ/vDP+fmyc/xadGL1R
# jjWmp2bIcmfbIWax1Jt4A8BQOujM8Ny8nkz+rwWWNR9XWrf/zvk9tyy29lTdyOcS
# Ok2uTIq3XJq0tyA9yn8iNK5+O2hmAUTnAU5GU5szYPeUvlM3kHND8zLDU+/bqv50
# TmnHa4xgk97Exwzf4TKuzJM7UXiVZ4vuPVb+DNBpDxsP8yUmazNt925H+nND5X4O
# pWaxKXwyhGNVicQNwZNUMBkTrNN9N6frXTpsNVzbQdcS2qlJC9/YgIoJk2KOtWbP
# JYjNhLixP6Q5D9kCnusSTJV882sFqV4Wg8y4Z+LoE53MW4LTTLPtW//e5XOsIzst
# AL81VXQJSdhJWBp/kjbmUZIO8yZ9HE0XvMnsQybQv0FfQKlERPSZ51eHnlAfV1So
# Pv10Yy+xUGUJ5lhCLkMaTLTwJUdZ+gQek9QmRkpQgbLevni3/GcV4clXhB4PY9bp
# YrrWX1Uu6lzGKAgEJTm4Diup8kyXHAc/DVL17e8vgg8CAwEAAaOB8jCB7zAfBgNV
# HSMEGDAWgBSgEQojPpbxB+zirynvgqV/0DCktDAdBgNVHQ4EFgQUU3m/WqorSs9U
# gOHYm8Cd8rIDZsswDgYDVR0PAQH/BAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wEQYD
# VR0gBAowCDAGBgRVHSAAMEMGA1UdHwQ8MDowOKA2oDSGMmh0dHA6Ly9jcmwuY29t
# b2RvY2EuY29tL0FBQUNlcnRpZmljYXRlU2VydmljZXMuY3JsMDQGCCsGAQUFBwEB
# BCgwJjAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuY29tb2RvY2EuY29tMA0GCSqG
# SIb3DQEBDAUAA4IBAQAYh1HcdCE9nIrgJ7cz0C7M7PDmy14R3iJvm3WOnnL+5Nb+
# qh+cli3vA0p+rvSNb3I8QzvAP+u431yqqcau8vzY7qN7Q/aGNnwU4M309z/+3ri0
# ivCRlv79Q2R+/czSAaF9ffgZGclCKxO/WIu6pKJmBHaIkU4MiRTOok3JMrO66BQa
# vHHxW/BBC5gACiIDEOUMsfnNkjcZ7Tvx5Dq2+UUTJnWvu6rvP3t3O9LEApE9GQDT
# F1w52z97GA1FzZOFli9d31kWTz9RvdVFGD/tSo7oBmF0Ixa1DVBzJ0RHfxBdiSpr
# hTEUxOipakyAvGp4z7h/jnZymQyd/teRCBaho1+VMIIF9TCCA92gAwIBAgIQHaJI
# MG+bJhjQguCWfTPTajANBgkqhkiG9w0BAQwFADCBiDELMAkGA1UEBhMCVVMxEzAR
# BgNVBAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4wHAYDVQQK
# ExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBSU0Eg
# Q2VydGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMTgxMTAyMDAwMDAwWhcNMzAxMjMx
# MjM1OTU5WjB8MQswCQYDVQQGEwJHQjEbMBkGA1UECBMSR3JlYXRlciBNYW5jaGVz
# dGVyMRAwDgYDVQQHEwdTYWxmb3JkMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQx
# JDAiBgNVBAMTG1NlY3RpZ28gUlNBIENvZGUgU2lnbmluZyBDQTCCASIwDQYJKoZI
# hvcNAQEBBQADggEPADCCAQoCggEBAIYijTKFehifSfCWL2MIHi3cfJ8Uz+MmtiVm
# KUCGVEZ0MWLFEO2yhyemmcuVMMBW9aR1xqkOUGKlUZEQauBLYq798PgYrKf/7i4z
# IPoMGYmobHutAMNhodxpZW0fbieW15dRhqb0J+V8aouVHltg1X7XFpKcAC9o95ft
# anK+ODtj3o+/bkxBXRIgCFnoOc2P0tbPBrRXBbZOoT5Xax+YvMRi1hsLjcdmG0qf
# nYHEckC14l/vC0X/o84Xpi1VsLewvFRqnbyNVlPG8Lp5UEks9wO5/i9lNfIi6iwH
# r0bZ+UYc3Ix8cSjz/qfGFN1VkW6KEQ3fBiSVfQ+noXw62oY1YdMCAwEAAaOCAWQw
# ggFgMB8GA1UdIwQYMBaAFFN5v1qqK0rPVIDh2JvAnfKyA2bLMB0GA1UdDgQWBBQO
# 4TqoUzox1Yq+wbutZxoDha00DjAOBgNVHQ8BAf8EBAMCAYYwEgYDVR0TAQH/BAgw
# BgEB/wIBADAdBgNVHSUEFjAUBggrBgEFBQcDAwYIKwYBBQUHAwgwEQYDVR0gBAow
# CDAGBgRVHSAAMFAGA1UdHwRJMEcwRaBDoEGGP2h0dHA6Ly9jcmwudXNlcnRydXN0
# LmNvbS9VU0VSVHJ1c3RSU0FDZXJ0aWZpY2F0aW9uQXV0aG9yaXR5LmNybDB2Bggr
# BgEFBQcBAQRqMGgwPwYIKwYBBQUHMAKGM2h0dHA6Ly9jcnQudXNlcnRydXN0LmNv
# bS9VU0VSVHJ1c3RSU0FBZGRUcnVzdENBLmNydDAlBggrBgEFBQcwAYYZaHR0cDov
# L29jc3AudXNlcnRydXN0LmNvbTANBgkqhkiG9w0BAQwFAAOCAgEATWNQ7Uc0SmGk
# 295qKoyb8QAAHh1iezrXMsL2s+Bjs/thAIiaG20QBwRPvrjqiXgi6w9G7PNGXkBG
# iRL0C3danCpBOvzW9Ovn9xWVM8Ohgyi33i/klPeFM4MtSkBIv5rCT0qxjyT0s4E3
# 07dksKYjalloUkJf/wTr4XRleQj1qZPea3FAmZa6ePG5yOLDCBaxq2NayBWAbXRe
# SnV+pbjDbLXP30p5h1zHQE1jNfYw08+1Cg4LBH+gS667o6XQhACTPlNdNKUANWls
# vp8gJRANGftQkGG+OY96jk32nw4e/gdREmaDJhlIlc5KycF/8zoFm/lv34h/wCOe
# 0h5DekUxwZxNqfBZslkZ6GqNKQQCd3xLS81wvjqyVVp4Pry7bwMQJXcVNIr5NsxD
# kuS6T/FikyglVyn7URnHoSVAaoRXxrKdsbwcCtp8Z359LukoTBh+xHsxQXGaSyns
# Cz1XUNLK3f2eBVHlRHjdAd6xdZgNVCT98E7j4viDvXK6yz067vBeF5Jobchh+abx
# KgoLpbn0nu6YMgWFnuv5gynTxix9vTp3Los3QqBqgu07SqqUEKThDfgXxbZaeTMY
# kuO1dfih6Y4KJR7kHvGfWocj/5+kUZ77OYARzdu1xKeogG/lU9Tg46LC0lsa+jIm
# LWpXcBw8pFguo/NbSwfcMlnzh6cabVgxggIzMIICLwIBATCBkTB8MQswCQYDVQQG
# EwJHQjEbMBkGA1UECBMSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHEwdTYWxm
# b3JkMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxJDAiBgNVBAMTG1NlY3RpZ28g
# UlNBIENvZGUgU2lnbmluZyBDQQIRANP4/upFzWc5gWkrbWGAMjcwCQYFKw4DAhoF
# AKB4MBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisG
# AQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcN
# AQkEMRYEFDWNARlVbYPUMp4KhcFdeYqbOYQ/MA0GCSqGSIb3DQEBAQUABIIBAH/b
# nGV7jWxN8yQaTyrSyIPv+Pj6gxuSQ+62VH9MA4LuXRgevsfl8eNsOglcg4mDdS1Y
# LUOSxZUKYL/CItr1AvBlunoHdGoRDI7bmMKbEJD17ymUBD/5EVFXXDEN2qd4Z8l5
# SkFMveTNPxJjiVV90YBE2RzDd2DSE4JY+t1qmFPNyfybkH8b3MlLxCiY7aQT7BAf
# Hdj2erYuap3VgonzS6ILQjKSmo/5iSwtYZXLm04NjcVlMUW+yLljPp/SSVZRtumP
# h75QO/EgaP8gWyjD3N3qxFam3qT+0y0i4vCgQp10iSOk9ugDQuC2v+K9gptnhJzn
# CpW3IKFtBlaOf4zlXWU=
# SIG # End signature block
