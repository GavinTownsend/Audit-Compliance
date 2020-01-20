<#
	.SYNOPSIS
		Exports a basic list of VM machines (for Hyper-V)
	
	.NOTES
		Script Name:	get-HV_VirtualMachineList.ps1
		Created By: 	Gavin Townsend
		Date: 			August 2019
		
	.DESCRIPTION
		The script performs the follow actions:
			- Exports a list of baisc machine data from Hyper-V cluster (does not need VMM)
			
		Helps discover non-domain joined machines, or those in DMZ environments
		
	.EXAMPLE
			.\get-HV_VirtualMachineList.ps1
			
	.REQUIREMENTS
		WinRM enabled on target machines (for WMI)
		Local administrator on target machines
		
		NB. Some WMI scans do not work on all operating systems (particularly older ones)
			
	.VERSION HISTORY
		1.0		Aug 2019	Gavin Townsend		Original Build
		
#>

$HyperVServer = Read-Host "Specify the Hyper-V Server to use (enter '.' for the local computer)"
$Log = "C:\Temp\Audit\$HyperVServer Server VM List $(get-date -f yyyy-MM-dd).txt"

$VMs = gwmi -namespace root\virtualization Msvm_ComputerSystem -computername $HyperVServer -filter "Caption = 'Virtual Machine'"
$table = @{}

foreach ($VM in [array] $VMs) {
	$query = "Associators of {$VM} Where AssocClass=Msvm_SystemDevice ResultClass=Msvm_KvpExchangeComponent"
	$Kvp = gwmi -namespace root\virtualization -query $query -computername $HyperVServer

	$xml = ($Kvp.GuestIntrinsicExchangeItems | ? {$_ -match "OSName"})
	$entry = $xml.Instance.Property | ?{$_.Name -eq "Data"}

	if ($entry.Value){
		$value = $entry.Value
	}
	elseif ($VM.EnabledState -ne 2){
		$value = "Offline"
	}
	else {
		$value = "Unknown"
	}
	
	if ($table.ContainsKey($value)){
		$table[$value] = $table[$value] + 1 
	}
	else {
		$table[$value] = 1
	}
}

$table.GetEnumerator() | Sort-Object Name | Format-Table -Autosize

$VMs | Export-Csv $Log -notype
write-host "Log Export Complete to $Log" -foregroundcolor yellow
