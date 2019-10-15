<#
	.SYNOPSIS
		Checks local anti-virus on selected computers
	
	.NOTES
		Script Name:	get-LOCAL_AVStatus.ps1
		Created By: 	Gavin Townsend
		Date: 			August 2019
		
	.DESCRIPTION
		The script performs the follow actions:
			- Makes a selection of computer objects (eg all Servers, selection of 100 computers)
			- Checks local AV Name and staus (ie is signature up to date)
			- Exports list for review
			
		
	.EXAMPLE
			.\get-LOCAL_AVStatus.ps1
			
			Update selection of $Computers as required
			
	.REQUIREMENTS
		Active Directory module
		WinRM enabled on target machines (for WMI)
		Local administrator on target machines
		
		NB. Namespace "root\SecurityCenter2" only exists on computers with Win 7 or later (does NOT exist on servers)
		
	.AUDIT CRITERIA
		Complete a discovery scan of anti-virus products and statuses
			
		Make a note of the following exceptions
			- Where an AV product is missing
			- Where the 'Definition Status' is out of date
			- Where the 'RealTime Status' is disabled

	.VERSION HISTORY
		1.0		Aug 2019	Gavin Townsend		Original Build
		
#>
Try{$Domain = $(get-addomain).dnsroot}
Catch{$Domain = ""}

$Log = "C:\temp\Audit\$Domain Local AV Status $(get-date -f yyyy-MM-dd).csv"

$Computers = Get-ADComputer -Filter {OperatingSystem -NOTLIKE "*server*" -AND Enabled -eq $TRUE} -Property Name 
$Computers = Get-Random -InputObject $Computers -Count 100

ForEach ($Computer in $Computers){
	$Computer = $Computer.name
	if(!(Test-Connection -Cn $Computer -BufferSize 16 -Count 1 -ea 0 -quiet)){
		write-host "WARNING: $Computer not accessible" -f yellow
	}
	else {
		function Get-AntiVirusProduct {
			[CmdletBinding()]
			param (
			[parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
			[Alias('name')]
			$computername=$computer)

			try { 
				#Get AV product
				write-host "Working on $computername"
				$AntiVirusProduct = Get-WmiObject -Namespace "root\SecurityCenter2" -Class AntiVirusProduct -ComputerName $computername -ErrorAction Stop 
				$AV = $AntiVirusProduct.displayName[0]  		#  <- Change to [1] to see additional AV products
				$Status = $AntiVirusProduct.productState[0]  	#  <- Change to [1] to see additional AV products
				
				# Get Status from Hex
    			$hex = [convert]::ToString($Status, 16).PadLeft(6,'0')
                $WSC_SECURITY_PRODUCT_STATE = $hex.Substring(2,2)
                $WSC_SECURITY_SIGNATURE_STATUS = $hex.Substring(4,2)		
			} 
			catch{ 
				Write-Warning "[ERROR $($computername)] : $_" 
				$NoAV+=$computername 
			} 
			
			$NoAV | out-file -Encoding Ascii -append "C:\Temp\Audit\$Domain No AV Data.txt"

			#Switch Status
			$DefinitionStatus = switch ($WSC_SECURITY_SIGNATURE_STATUS){
				"00" {"UP TO DATE"}
				"10" {"OUT OF DATE"}
				default {"UNKNOWN"}
			}  
		
			$RealTimeProtectionStatus = switch ($WSC_SECURITY_PRODUCT_STATE){
				"00" {"OFF"} 
				"01" {"EXPIRED"}
				"10" {"ON"}
				"11" {"SNOOZED"}
				default {"UNKNOWN"}
			}
 
			<#switch ($Status) {
				"266240" {$DefinitionStatus = "Up to date" ;$RealTimeProtectionStatus = "Enabled"} 
				"397312" {$DefinitionStatus = "Up to date" ;$RealTimeProtectionStatus = "Enabled"}
				"397568" {$DefinitionStatus = "Up to date" ;$RealTimeProtectionStatus = "Enabled"}
				
				"393216" {$DefinitionStatus = "Up to date" ;$RealTimeProtectionStatus = "Disabled"}
				"262144" {$DefinitionStatus = "Up to date" ;$RealTimeProtectionStatus = "Disabled"}
				"393472" {$DefinitionStatus = "Up to date" ;$RealTimeProtectionStatus = "Disabled"}
				
				"266256" {$DefinitionStatus = "Out of date" ;$RealTimeProtectionStatus = "Enabled"}
				"397328" {$DefinitionStatus = "Out of date" ;$RealTimeProtectionStatus = "Enabled"}
				"397584" {$DefinitionStatus = "Out of date" ;$RealTimeProtectionStatus = "Enabled"}
				
				"262160" {$DefinitionStatus = "Out of date" ;$RealTimeProtectionStatus = "Disabled"}
				"393232" {$DefinitionStatus = "Out of date" ;$RealTimeProtectionStatus = "Disabled"}
				"393488" {$DefinitionStatus = "Out of date" ;$RealTimeProtectionStatus = "Disabled"}

				default {$DefinitionStatus = "Unknown" ;$RealTimeProtectionStatus = "Unknown"}
			}
			#>
						
			#Generate Array
			$obj = @{}
			$obj.Computername = $computername
			$obj.Antivirus = $AV
			$obj.'ProductExe' = $AntiVirusProduct.pathToSignedProductExe
			$obj.'ReportingExe' = $AntiVirusProduct.pathToSignedReportingExe
			$obj.'DefinitionStatus' = $DefinitionStatus
			$obj.'RealTimeStatus' = $RealTimeProtectionStatus
						
			New-Object -TypeName PSObject -Property $obj 
		}

		Get-AntiVirusProduct | select Computername,Antivirus,DefinitionStatus,RealTimeStatus | export-csv -append -path $Log -NTI -Encoding UTF8
	}
}

write-host ""
write-host "CSV Export Complete to $Log"
