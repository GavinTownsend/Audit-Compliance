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
		
	.AUDIT CRITERIA
		Complete a discovery scan of windows update history
		
		Collect a good sized random sample from both Servers and Computers (ensure to rename output file, to avoid overwriting)
			
		Make a note of any Warnings for 'Old' or 'Very Old' events
	
	.VERSION HISTORY
		1.0		Aug 2019	Gavin Townsend		Original Build
		
#>


$Domain = $(get-addomain).dnsroot
$Log = "C:\temp\Audit\$Domain Update History $(get-date -f yyyy-MM-dd).csv"

$Computers = Get-ADComputer -Filter {OperatingSystem -LIKE "*server*" -AND Enabled -eq $TRUE} -Property Name  
#$Computers = Get-ADComputer -Filter {OperatingSystem -NOTLIKE "*server*" -AND Enabled -eq $TRUE} -Property Name
$Computers = Get-Random -InputObject $Computers -Count 100

$obj=@()
$Data = @()
$Events = 10  # <- Events to collect per machine

$Old = (get-date).AddDays(-14)
$OldCount = 0
$VeryOld = (get-date).AddDays(-30)
$VeryOldCount = 0

foreach ($Computer in $Computers.name) {

	if(!(Test-Connection -Cn $Computer -BufferSize 16 -Count 1 -ea 0 -quiet)){
		write-host "WARNING: $Computer not accessible" -f yellow
	}
	else {
		try{
			write-host "Working on $Computer"
			
			$Session = [activator]::CreateInstance([type]::GetTypeFromProgID("Microsoft.Update.Session",$Computer))
			$Searcher= $Session.CreateUpdateSearcher()
			$History = $Searcher.QueryHistory(0, $Events)

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

$Data | sort-object -property Computer,Date -descending | Export-Csv $Log -notype

write-host ""
write-host "There were $EventCount Windows Update events listed from $ComputerCount computers"
write-host "$RecentCount events are recent"
write-host "$OldCount events are old" -foregroundcolor yellow
write-host "$VeryOldCount events are very old" -foregroundcolor red
write-host ""
write-host "Log Export Complete to $Log" 
