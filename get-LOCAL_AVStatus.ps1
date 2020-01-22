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
			- Runs two passes, looking for additional AV products that may have been installed over time
			- Exports list for review
			
		
	.EXAMPLE
			.\get-LOCAL_AVStatus.ps1
			
			Update selection of $Computers as required
			
	.REQUIREMENTS
		Active Directory module
		WinRM enabled on target machines (for WMI)
		Local administrator on target machines

        O365 PowerShell plugins https://docs.microsoft.com/en-us/office365/enterprise/powershell/connect-to-office-365-powershell
		
		#Connect as a Non MFA enabled user
			$AdminCred = Get-Credential admin@example.com
			Connect-MsolService -Credential $AdminCred

		#Connect as an MFA enabled user (login GUI)
			Connect-MsolService
		
		Global administrator role

		
		NB. Namespace "root\SecurityCenter2" only exists on computers with Win 7 or later (does NOT exist on servers)
		
	.AUDIT CRITERIA
		Complete a discovery scan of anti-virus products and statuses
			
		Make a note of the following exceptions
			- Where an AV product is missing (computers are logged to the 'No AV Data' log)
			- Where the 'Definition Status' is out of date
			- Where the 'RealTime Status' is disabled

	.VERSION HISTORY
		1.0		Aug 2019	Gavin Townsend		Original Build
		1.1		Jan 2020	Gavin Townsend		Added 2nd pass to collect additional AV products (eg Kaspersky installed after Defender)
#>
Try{$Domain = $(get-addomain).dnsroot}
Catch{$Domain = ""}

$Log = "C:\temp\Audit\$Domain Local AV Status $(get-date -f yyyy-MM-dd).csv"

try{
    $Computers = Get-ADComputer -Filter {OperatingSystem -NOTLIKE "*server*" -AND Enabled -eq $TRUE} -Property Name 
    $Auth= "AD"
}
Catch{
    $Computers = Get-MsolDevice -All |? {$_.Enabled -eq $True -and $_.DeviceOsType -eq "Windows"} | Select DisplayName
    $Auth="Azure"
}

$Computers = Get-Random -InputObject $Computers -Count 100

ForEach ($Computer in $Computers){
	if ($Auth -eq "AD"){
        $Computer = $Computer.name
    }
    else{
       $Computer = $Computer.DisplayName
    }
 
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
				#Get First AV product
				write-host "Checking $computername for first AV"
				$AntiVirusProduct = Get-WmiObject -Namespace "root\SecurityCenter2" -Class AntiVirusProduct -ComputerName $computername -ErrorAction Stop 
				$AV = $AntiVirusProduct.displayName[0] 
				$Status = $AntiVirusProduct.productState[0] 
				
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
		
		function Get-AntiVirusProduct2 {
			[CmdletBinding()]
			param (
			[parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
			[Alias('name')]
			$computername=$computer)

			try { 
				#Get AV product
				write-host "Checking $computername for a second AV"
				$AntiVirusProduct2 = Get-WmiObject -Namespace "root\SecurityCenter2" -Class AntiVirusProduct -ComputerName $computername -ErrorAction Stop 
				$AV2 = $AntiVirusProduct2.displayName[1] 
				$Status2 = $AntiVirusProduct2.productState[1]
				
				# Get Status from Hex
    			$hex2 = [convert]::ToString($Status2, 16).PadLeft(6,'0')
                $WSC_SECURITY_PRODUCT_STATE2 = $hex2.Substring(2,2)
                $WSC_SECURITY_SIGNATURE_STATUS2 = $hex2.Substring(4,2)		
			} 
			catch{ 
				Write-Warning "[ERROR $($computername)] : $_" 
				$NoAV2+=$computername 
			} 
			
			$NoAV2 | out-file -Encoding Ascii -append "C:\Temp\Audit\$Domain No AV2 Data.txt"

			#Switch Status
			$DefinitionStatus2 = switch ($WSC_SECURITY_SIGNATURE_STATUS2){
				"00" {"UP TO DATE"}
				"10" {"OUT OF DATE"}
				default {"UNKNOWN"}
			}  
		
			$RealTimeProtectionStatus2 = switch ($WSC_SECURITY_PRODUCT_STATE2){
				"00" {"OFF"} 
				"01" {"EXPIRED"}
				"10" {"ON"}
				"11" {"SNOOZED"}
				default {"UNKNOWN"}
			}

						
			#Generate Array
			$obj2 = @{}
			$obj2.Computername = $computername
			$obj2.Antivirus = $AV2
			$obj2.'ProductExe' = $AntiVirusProduct2.pathToSignedProductExe
			$obj2.'ReportingExe' = $AntiVirusProduct2.pathToSignedReportingExe
			$obj2.'DefinitionStatus' = $DefinitionStatus2
			$obj2.'RealTimeStatus' = $RealTimeProtectionStatus2
						
			New-Object -TypeName PSObject -Property $obj2
		}

		Get-AntiVirusProduct | select Computername,Antivirus,DefinitionStatus,RealTimeStatus | export-csv -append -path $Log -NTI -Encoding UTF8
		Get-AntiVirusProduct2 | select Computername,Antivirus,DefinitionStatus,RealTimeStatus | export-csv -append -path $Log -NTI -Encoding UTF8
	}
}

write-host ""
write-host "CSV Export Complete to $Log"
