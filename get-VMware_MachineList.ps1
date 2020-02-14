<#
	.SYNOPSIS
		Exports a basic list of VM machines (for VMware)
	
	.NOTES
		Script Name:	get-VM_VirtualMachineList.ps1
		Created By: 	Gavin Townsend
		Date: 			August 2019
		
	.DESCRIPTION
		The script performs the follow actions:
			- Exports a list of baisc machine data from vCenter 
			
		Helps discover non-domain joined machines, or those in DMZ environments
		
	.EXAMPLE
			.\get-VM_VirtualMachineList.ps1
			
	.REQUIREMENTS
		VMware PowerCLI

			
	.VERSION HISTORY
		1.0		Aug 2019	Gavin Townsend		Original Build
		
#>


$ViServer = Read-Host "Specify the vCenter Server to use (enter '.' for the local computer)"
$Log = "C:\Temp\Audit\$ViServer VM List $(get-date -f yyyy-MM-dd).csv"

connect-viserver $ViServer
$VMs = Get-VM  | Select-Object Name, Vmhost, PowerState, @{N="ToolsStaus"; E={$_.extensiondata.guest.toolsversionstatus}}, @{N="Operating system"; E={@($_.guest.OSfullname)}} 
$VMs | Export-Csv $Log -notype
$VMCount = $VMs.count

write-Host ""
write-Host "---------------------------------------------------"
write-Host "Script Output Summary - VMware Virtual Machines $(Get-Date)"
write-Host ""
write-Host "VM count: $VMCount"
write-Host ""
write-Host "---------------------------------------------------"
write-Host ""
Write-Host "VMware scanning tests concluded. Please review log $Log"
