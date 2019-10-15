<#
	.SYNOPSIS
		Checks web content filtering by downloading EICAR test file and testing accessibility to known bad sites
	
	.NOTES
		Script Name:	test-WEB_ContentFiltering.ps1
		Created By:		Gavin Townsend
		Date:			August 2019
		
	.DESCRIPTION
		The script performs the follow actions:
			- Downloads EICAR test file (HTTP and HTTPS)
			- Checks website availability from a set of URLs	
			
	.AUDIT CRITERIA
		Test a download of EICAR virus files and check if inappropriate websites are blocked
			- All test files should be blocked 
			- All website should be blocked 
			
		Note any Warnings
		
	.EXAMPLE
			.\test-WEB_ContentFiltering.ps1
			
	.REQUIREMENTS
		Run from typical machine (with Internet Access) as end user
		
		Test AV source		http://2016.eicar.org/85-0-Download.html
		
		Blacklist source	http://www.squidguard.org/blacklists.html
		
		Online Port Scan	https://hackertarget.com/nmap-online-port-scanner/
		
	.VERSION HISTORY
		1.0		Aug 2019	Gavin Townsend		Original Build
		
#>
Try{$Domain = $(get-addomain).dnsroot}
Catch{$Domain = ""}

$Log = "C:\temp\Audit\$Domain Web Content Filter $(get-date -f yyyy-MM-dd).txt"

Function Write-Log {
   Param ([string]$LogString)
   Add-content $Log -value $LogString
}
write-log "$(Get-Date) - START: New Script run from $Env:Computername"


#Antivirus Test Files
$HTTP = "http://2016.eicar.org/download/eicar.com"
$HTTPS = "https://secure.eicar.org/eicar.com"
$TestFile = "c:\temp\audit\eicar.com"

Try{
	Invoke-WebRequest -Uri $HTTP -OutFile $TestFile
		Write-Host "WARNING: HTTP File writen to $TestFile" -foregroundcolor yellow
		Write-LOG "`t WARNING: HTTP File writen to $TestFile" 
}
catch{
	write-Host "SUCESS: HTTP File blocked when writing to $TestFile" -foregroundcolor green
	Write-LOG "`t SUCCESS: HTTP File blocked when writen to $TestFile" 
}

Try{
	Invoke-WebRequest -Uri $HTTPS -OutFile $TestFile
		Write-Host "WARNING: HTTPS File writen to $TestFile" -foregroundcolor yellow
		Write-LOG "`t WARNING: HTTPS File writen to $TestFile" 
}
catch{
	write-Host "SUCESS: HTTPS File blocked when writing to $TestFile" -foregroundcolor green
	Write-LOG "`t SUCCESS: HTTPS File blocked when writen to $TestFile" 
}


#Check Bad URLs
$URLs =@("http:\\evildooinz.com",
	"http:\\pornhub.com",
	"http:\\mp3.com.au",
	"http:\\xxx.com",
	"http:\\bet365.com",
	"http:\\proxybay.pro",
	"http:\\yadro.ru",
	"http:\\warez.com",
	"http:\\torrentz.eu",
	"http:\\cheats.ru")

foreach ($URL in $URLs){
	
	Try{
		$HTTP_Request = [System.Net.WebRequest]::Create($URL)
		$HTTP_Response = $HTTP_Request.GetResponse()
		$HTTP_Status = [int]$HTTP_Response.StatusCode
		
		If ($HTTP_Status -eq 200) {
			Write-Host "WARNING: $URL is accessible" -foregroundcolor yellow
			Write-LOG "`t WARNING: $URL is accessible" 
		}
		Else {
			Write-Host "SUCCESS: $URL is not accessible" -foregroundcolor green
			Write-LOG "`t SUCCESS: $URL is accessible" 
		}
	}
	catch{
			Write-Host "SUCCESS: $URL is not available" -foregroundcolor green
			Write-LOG "`t SUCCESS: $URL is not available" 
	}
}

write-Host ""
Write-Host "Content Filter tests concluded. Please review $Log and your AV software logs."
