<#
	.SYNOPSIS
		Gets the latest Windows Update History for a list of machines
	
	.NOTES
		Script Name:	get-LOCAL_UpdateHistory.ps1
		Created By:		Gavin Townsend
		Date:			August 2019
		
	.DESCRIPTION
		The script performs the follow actions:
			- Gets a random list of servers or computers
			- Collects most recent Windows Updates		
			- Rates age of update events
		
	.EXAMPLE
			.\get-LOCAL_UpdateHistory.ps1
			
	.REQUIREMENTS
		Active Directory module
		WinRM enabled on target machines (for WMI)
		Local administrator on target machines
		
		NB. Some WMI scans do not work on all operating systems (particularly older ones)
		
		
		O365 PowerShell plugins https://docs.microsoft.com/en-us/office365/enterprise/powershell/connect-to-office-365-powershell
		
			Install-Module MSOnline
		
		#Connect as a Non MFA enabled user
			$AdminCred = Get-Credential admin@example.com
			Connect-MsolService -Credential $AdminCred

		#Connect as an MFA enabled user (login GUI)
			Connect-MsolService
			
		
	.AUDIT CRITERIA
		Complete a discovery scan of windows update history
		
		Collect a good sized random sample from both Servers and Computers (ensure to rename output file, to avoid overwriting)
			
		Make a note of any Warnings for 'Old' or 'Very Old' events
	
	.VERSION HISTORY
		1.0		Aug 2019	Gavin Townsend		Original Build
		
#>


Try{$Domain = $(get-addomain).dnsroot}
Catch{$Domain = ""}

$Log = "C:\temp\Audit\$Domain Update History $(get-date -f yyyy-MM-dd).csv"

try{
    $Recent = (Get-Date).AddDays(-1)
    $Computers = Get-ADComputer -Filter {OperatingSystem -NOTLIKE "*server*" -AND Enabled -eq $TRUE -AND lastlogondate -gt $Recent } -Property Name
    $Auth= "AD"
}
Catch{
    $Computers = Get-MsolDevice -All |? {$_.Enabled -eq $True -and $_.DeviceOsType -eq "Windows"} | Select DisplayName
    $Auth="Azure"
}

$MachinesToScanCount = 50
$Computers = Get-Random -InputObject $Computers -Count $MachinesToScanCount

$obj=@()
$Data = @()
$Events = 10  # <- Events to collect per machine

$Old = (get-date).AddDays(-14)
$OldCount = 0
$VeryOld = (get-date).AddDays(-30)
$VeryOldCount = 0

foreach ($Computer in $Computers) {
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
		try{
			write-host "Working on $Computer"
			
			$Session = [activator]::CreateInstance([type]::GetTypeFromProgID("Microsoft.Update.Session",$Computer))
			$Searcher= $Session.CreateUpdateSearcher()
			$History = $Searcher.QueryHistory(0, $Events)

			<#  Event Log Alternative (NB. logs may be cleared, so not alway accurate)
			
			$History = Get-WinEvent -ComputerName $Computer -MaxEvents $Events @{
				Logname='System'
				ID=19
				ProviderName='Microsoft-Windows-WindowsUpdateClient'
			} | ForEach-Object  {
				[PSCustomObject]@{
					Date = $_.TimeCreated
					Title = $_.Properties.Value[0]
				}
			}
			
			#>

			$ComputerCount++
			
			Foreach($Entry in $History | ?{$_.Title -NOTLIKE "*Defender*"}) {
				$obj = New-Object -TypeName PSObject
				$obj | Add-Member -MemberType NoteProperty -Name "Computer" -Value $Computer
				$obj | Add-Member -MemberType NoteProperty -Name "Date" -Value $Entry.Date
				$obj | Add-Member -MemberType NoteProperty -Name "Description" -Value $Entry.Title

				$EventCount++
				if ($Entry.Date -le $VeryOld){
					$obj | Add-Member -MemberType NoteProperty -Name "Age" -Value "Very Old"
					$VeryOldCount++
				}
				elseif ($Entry.Date -le $Old){
					$obj | Add-Member -MemberType NoteProperty -Name "Age" -Value "Old"
					$OldCount++
				}
				else{
					$obj | Add-Member -MemberType NoteProperty -Name "Age" -Value "Recent"
					$RecentCount++
				}
				
				$Data += $obj
			}
		}
		catch{
			write-host "WARNING: $Computer not accessible" -foregroundcolor yellow
		}
	}
}

$Data | sort-object -property Computer,Date -descending | Export-Csv $Log -notype -Encoding UTF8

write-Host ""
write-Host "--------------------------------------------------------"
write-Host "Script Output Summary - Local Update History Scan $(Get-Date)"
write-Host ""
Write-Host "There were $EventCount Windows Update events listed from $ComputerCount computers"
write-host ""
write-host "Recent Events: $RecentCount" -foregroundcolor green
write-host "Old Events: $OldCount" -foregroundcolor yellow
write-host "Very Old Events: $VeryOldCount" -foregroundcolor red
write-host ""
write-Host "--------------------------------------------------------"
write-host "Local update history scan complete. Log Export Complete to $Log"
