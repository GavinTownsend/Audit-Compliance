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
		
		Blacklist sources	https://knowledgebase.paloaltonetworks.com/KCSArticleDetail?id=kA10g000000Cm5hCAC
							http://www.squidguard.org/blacklists.html
		
	.VERSION HISTORY
		1.0		Aug 2019	Gavin Townsend		Original Build
		1.1		Jan 2020	Gavin Townsend		Upated to WGET method
		
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
$VirusWrite = 0
$VirusBlock = 0

Try{
	Invoke-WebRequest -Uri $HTTP -OutFile $TestFile
		Write-Host "WARNING: HTTP File writen to $TestFile" -foregroundcolor yellow
		Write-LOG "`t WARNING: HTTP File writen to $TestFile" 
		$VirusWrite++
}
catch{
	write-Host "SUCESS: HTTP File blocked when writing to $TestFile" -foregroundcolor green
	Write-LOG "`t SUCCESS: HTTP File blocked when writen to $TestFile" 
	$VirusBlock++
}

Try{
	Invoke-WebRequest -Uri $HTTPS -OutFile $TestFile
		Write-Host "WARNING: HTTPS File writen to $TestFile" -foregroundcolor yellow
		Write-LOG "`t WARNING: HTTPS File writen to $TestFile" 
		$VirusWrite++
}
catch{
	write-Host "SUCESS: HTTPS File blocked when writing to $TestFile" -foregroundcolor green
	Write-LOG "`t SUCCESS: HTTPS File blocked when writen to $TestFile" 
	$VirusBlock++
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
	"http:\\torrentspy.com",
	"http:\\cheats.ru",
	"www.cannabis.com",
	"www.playboyplus.com",
	"www.redtube.com",
	"www.kkk.com",
	"www.hackspc.com",
	"www.nudistbeaches.nl",
	"www.thepiratebay.org",
	"www.emule-project.net",
	"www.collegehumor.com",
	"www.grabagun.com",
	"http:\\newasp.com.cn",
	"http:\\bx4.com",
	"http:\\allpasswords.com",
	"http:\\myproxy.ca",
	"http:\\webproxy.ca",
	"http:\\bypass.cc")

$OpenCount = 0
$BlockCount = 0

foreach ($URL in $URLs){
	$HTTP_Status = $NULL
	Try{
		$HTTP_Status = wget $URL | % {$_.StatusCode}
		
		If ($HTTP_Status -eq 200) {
			Write-Host "WARNING: $URL is accessible" -foregroundcolor yellow
			Write-LOG "`t WARNING: $URL is accessible" 
			$OpenCount++
		}
		Else {
			Write-Host "SUCCESS: $URL is not accessible" -foregroundcolor green
			Write-LOG "`t SUCCESS: $URL is accessible" 
			$BlockCount++
		}
	}
	catch{
			Write-Host "SUCCESS: $URL is not available" -foregroundcolor green
			Write-LOG "`t SUCCESS: $URL is not available" 
			$BlockCount++
	}
}

write-Host ""
write-Host "--------------------------------------------------------------"
write-Host "Script Output Summary - Content Filtering $(Get-Date) "
write-Host ""
write-Host "Test virus files downloaded to disk: $VirusWrite" -foregroundcolor yellow
write-Host "Test virus files blocked: $VirusBlock" -foregroundcolor green
write-Host ""
write-Host "Suspicious sites openly available: $OpenCount" -foregroundcolor yellow
write-Host "Suspicious sites failed to connect: $BlockCount" -foregroundcolor green
write-Host ""
write-Host "--------------------------------------------------------------"
write-Host ""
Write-Host "Content Filter tests concluded. Please review $Log and your AV software logs."
