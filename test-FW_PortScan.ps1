<#
	.SYNOPSIS
		Scans common firewall ports to see if they are being filtered
	
	.NOTES
		Script Name:	test-FW_PortScan.ps1
		Created By:		Gavin Townsend
		Date:			August 2019
		
	.DESCRIPTION
		The script performs the follow actions:
			- Test common outbound ports to public test service
			- Tests common inbound ports (optionally against public IP)	

	.AUDIT CRITERIA
		Complete a scan of common outbound and inbound ports
			- Some outbound ports may be open, but ideally there is some filtering in place (restricting traffic to services only where required)
			- Inbound ports should all be filtered
		
		Note any Warnings
	
	.EXAMPLE
			.\test-FW_PortScan.ps1
			
	.REQUIREMENTS
		Run from typical machine (with Internet Access) as end user
		
		NB. Depending on routing, the inbound port scan may need to be run externally from the corporate network
		
		Egress Port Scanner Reference	https://www.blackhillsinfosec.com/poking-holes-in-the-firewall-egress-testing-with-allports-exposed/
		
		Alternative Inbound Port Scan	https://hackertarget.com/nmap-online-port-scanner/
		
	.VERSION HISTORY
		1.0		Aug 2019	Gavin Townsend		Original Build
		
#>


Try{$Domain = $(get-addomain).dnsroot}
Catch{$Domain = ""}

$Log = "C:\temp\Audit\$Domain FW Scan $(get-date -f yyyy-MM-dd).txt"

Function Write-Log {
   Param ([string]$LogString)
   Add-content $Log -value $LogString
}
write-log "$(Get-Date) - START: New Script run from $Env:Computername"

#Outbound Scanning
$OutPorts = @("21","22","23","25","53","67","68","80","110","139","389","443","445","636","1433","3389","8080")
$OutboundTarget = "allports.exposed"

write-Host "Starting outbound port scanning to $OutboundTarget"
write-log "`t Starting outbound port scanning to $OutboundTarget"

$OutBlock = 0
$OutOpen = 0

$OutPorts | % {$test= new-object system.Net.Sockets.TcpClient; $wait = $test.beginConnect($OutboundTarget,$_,$null,$null);($wait.asyncwaithandle.waitone(250,$false))
	if($test.Connected){
		write-Host "WARNING: Outbound port $_ is open" -foregroundcolor yellow
		Write-LOG "`t WARNING: Outbound port $_ is open" 
		$OutOpen++
	}
	else{
		write-Host "SUCCESS: Outbound port $_ is filtered" -foregroundcolor green
		Write-LOG "`t SUCCESS: Outbound port $_ is filtered" 
		$OutBlock++
	}
} | select-string " "


#Inbound Scanning
$InPorts = @("21","22","23","25","53","67","68","80","110","139","389","443","445","636","1433","3389","8080")
$InboundTarget = Read-Host "Enter IP for inbound scan (or type 'p' to get public address)"

if ($InboundTarget -eq "p"){
	Try{
		$InboundTarget = Invoke-RestMethod http://ipinfo.io/json | Select -exp ip
			Write-Host "SUCCESS: Public IP is $InboundTarget" -foregroundcolor green
			Write-LOG "`t SUCCESS: Public IP is $InboundTarget" 
	}
	catch{
		write-Host "WARNING: Unable to get public IP" -foregroundcolor yellow
		Write-LOG "`t WARNING: Unable to get public IP" 
		$InboundTarget = Read-Host "Enter IP for inbound scan"
	}
}


write-Host "Starting inbound port scanning to $InboundTarget"
write-log "`t Starting inbound port scanning to $InboundTarget"

$InBlock = 0
$InOpen = 0

$InPorts | % {$test= new-object system.Net.Sockets.TcpClient; $wait = $test.beginConnect($InboundTarget,$_,$null,$null);($wait.asyncwaithandle.waitone(250,$false))
	if($test.Connected){
		write-Host "WARNING: Inbound port $_ is open" -foregroundcolor yellow
		Write-LOG "`t WARNING: Inbound port $_ is open" 
		$InOpen++
	}
	else{
		write-Host "SUCCESS: Inbound port $_ is filtered" -foregroundcolor green
		Write-LOG "`t SUCCESS: Inbound port $_ is filtered" 
		$InBlock++
	}
} | select-string " "


write-Host ""
write-Host "---------------------------------------------------"
write-Host "Script Output Summary - Port Scan $(Get-Date)"
write-Host ""
write-Host "Outbound ports open: $OutOpen" -foregroundcolor yellow
write-Host "Outbound ports blocked: $OutBlock" -foregroundcolor green
write-Host "Inbound ports open: $InOpen" -foregroundcolor yellow
write-Host "Inbound ports blocked: $InBlock" -foregroundcolor green
write-Host ""
write-Host "---------------------------------------------------"
write-Host ""
Write-Host "Firewall scanning tests concluded. Please review $Log"
