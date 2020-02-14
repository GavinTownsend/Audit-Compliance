
<#
	.SYNOPSIS
		RUN THIS SCRIPT FIRST

		It checks on permissions and plugins required to complete audit scripts
		
	.NOTES
		Script Name:	PreCheck.ps1
		Created By: 	Gavin Townsend
		Date: 			August 2019
		
	.DESCRIPTION
		The script performs the follow actions:
			- Checks/creates local audit folder and log file
			- Checks script user has appropriate access (group memberships)
			- Checks plugins for ActiveDirectory, Exchange, Azure, VMware
			- Runs some sample cmdlets to test connectivity and permissions
			- Checks if WinRM service is running
	
	.AUDIT CRITERIA
		Confirm that the environment is ready for auditing
			- User is a member of relevant groups
			- Plugins are available
			- Remote PS management is available
			- Sufficient permissions
			
		Note any Warnings

	.EXAMPLE
			.\PreCheck.ps1
			
	.REQUIREMENTS
		Powershell v3
			
	.VERSION HISTORY
		1.0		Aug 2019	Gavin Townsend		Original Build
		
#>


#Get relevant enviornment info
$Script = $MyInvocation.MyCommand.Name
$Domain = $(get-addomain).dnsroot
$ScriptUser = $env:username  #ScriptUser = Get-Credential -Message "Admin account required to run scripts"}


#Log path
Write-Host""
Write-Host "Checking that the folder C:\Audit exists (for log files)"
write-Host "--------------------------------------------------------"
write-host ""
$Path = "C:\Temp\Audit\"
If(test-path $Path){
	Write-Host "SUCCESS: $Path is available" -foregroundcolor green
}
else{
	$Create = Read-Host -Prompt "The folder $Path is required to save Audit logs - create it now (Y/N)?"
	while("Y","y","N","n" -notcontains $Create){
		$Create = Read-Host -Prompt "The folder $Path is required to save Audit logs - create it now (Y/N)?"
	}
	
	if($Create -eq 'y' -OR $Create -eq 'Y'){
		New-Item -ItemType Directory -Force -Path $Path
		Write-Host "INFO: New folder $Path created" -foregroundcolor yellow
	}
	Else{
		write-Host "WARNING: Logs folder does not exist. Please create the folder $Path manually and start checks again." -foregroundcolor red
		exit
	}
}


$Log = $Path + "$Domain PreCheck $(get-date -f yyyy-MM-dd).log"

Function Write-Log {
   Param ([string]$LogString)
   Add-content $Log -value $LogString
}
write-log "$(Get-Date) - START: $Script run from $Env:Computername by $ScriptUser"


#Check Group Memberships
write-log "`t START: Function CheckGroupMembership"
Write-Host " "

function Get-NestedGroupMember  {
  [CmdletBinding()] 
	param(
		[Parameter(Mandatory)] 
		[string]$Group 
	)
	$GroupMember = $False
	Try{
		$members = Get-ADGroupMember -Identity $Group | sort-object objectClass -descending
		
		foreach ($member in $members){
			$Name = $member.SamAccountName
			$Display = $member.Name
			
			#Users
			if ($member.objectClass -eq 'user') {
				If ($Name -eq $ScriptUser) {
					$GroupMember = $True
				}
			}
			#Groups
			if ($member.objectClass -eq 'group') {
				Get-NestedGroupMember -Group $Display #$member.distinguishedName
			}
		}
		if ($GroupMember -eq $True){
			write-log "`t`t SUCCESS: $ScriptUser is a member of the group $Group"
			Write-Host "SUCCESS: $ScriptUser is a member of the group $Group" -foregroundcolor green
		}
		else{
			write-log "`t`t WARNING: $ScriptUser is NOT a member of the group $Group"
			write-Host "WARNING: $ScriptUser is NOT a member of the group $Group" -foregroundcolor yellow
		}
	}
	catch{
		Write-log "`t`t ERROR: $($_.Exception.Message)"
		write-log "$(Get-Date) - End Log Entry"
		break
	}
}

Write-Host "Checking that the current user has domain level permissions"
write-Host "-----------------------------------------------------------"
write-host ""
Get-NestedGroupMember -Group "Administrators"
Get-NestedGroupMember -Group "Domain User Administrators"
Get-NestedGroupMember -Group "Exchange Recipient Administrators"


#Check Modules and Plugins
write-log "`t START: Checking Modules"
Write-Host " "
Function CheckModule{
	Param ([string]$Module)
	Process{
		try{
			if (Get-Module -ListAvailable -Name $Module) {
				Write-log "`t`t SUCCESS: $Module available" 
				Write-Host "SUCCESS: $Module is available" -foregroundcolor green
			} 
			else {
				Write-Host "WARNING: $Module not available" -foregroundcolor yellow
			}
		}	
		catch{
			Write-log "`t`t ERROR: $($_.Exception.Message)"
			write-log "$(Get-Date) - End Log Entry"
			break
		}
	}
}

Write-Host "Checking that PowerShell modules are available"
write-Host "----------------------------------------------"
write-host ""
CheckModule ActiveDirectory
CheckModule MSOnline
CheckModule Hyper-V

write-log "`t START: Checking Plugins"
Write-Host " "
Function CheckPlugin{
	Param ([string]$Plugin)
	Process{
		try{
			if (Get-PSSnapin | where {$_.Name -eq $Plugin}){
				Write-log "`t`t SUCCESS: $Plugin available"
				Write-Host "SUCCESS: $Plugin is available" -foregroundcolor green
			}
			else{
				Write-log "`t`t WARNING: $Plugin not available"
				Write-Host "WARNING: $Plugin not available" -foregroundcolor yellow
			}

		}	
		catch{
			Write-log "`t`t ERROR: $($_.Exception.Message)"
			write-log "$(Get-Date) - End Log Entry"
			break
		}
	}
}

Write-Host "Checking that PowerShell plugins are avaialble"
write-Host "----------------------------------------------"
write-host ""
CheckPlugin Microsoft.Exchange.Management.PowerShell.E2010
CheckPlugin Microsoft.Exchange.Management.PowerShell.E2013
CheckPlugin Microsoft.Exchange.Management.PowerShell.E2016
CheckPlugin VMware.VimAutomation.Core


write-log "`t START: Checking Application Folders"
Write-Host " "
Function CheckFolder{
	Param ([string]$Folder)
	Process{
		try{
			if (Test-Path $Folder) {
				Write-log "`t`t SUCCESS: $Folder available"
				Write-Host "SUCCESS: $Folder is available" -foregroundcolor green
			}
			else{
				Write-log "`t`t WARNING: $Folder not available"
				Write-Host "WARNING: $Folder not available" -foregroundcolor yellow
			}

		}	
		catch{
			Write-log "`t`t ERROR: $($_.Exception.Message)"
			write-log "$(Get-Date) - End Log Entry"
			break
		}
	}
}

CheckFolder "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI"
CheckFolder "C:\Program Files\VMware\Infrastructure\vSphere PowerCLI"


#Test Computer Enumeration
write-host ""
Write-Host "Checking lookup against Active Directory and O365"
write-Host "-------------------------------------------------"
write-host ""
write-log "`t START: Checking Computer Enumeration"
try{
	$sw = [Diagnostics.Stopwatch]::StartNew()
	$Test = Get-ADComputer -Filter * -ErrorAction stop
    $sw.Stop()
	$Time = ($sw.Elapsed).Seconds
	write-host "Active Directory computer lookup sucessful - Full enumeration in $Time second(s)" -foregroundcolor green
	Write-log "`t`t SUCCESS: AD Compter enumeration in $Time second(s)"
	$Auth= "AD"
}
Catch{
	write-host "Unable to lookup computers in Active Directory - If AD is used, check plugin and permissions" -foregroundcolor yellow
	Write-log "`t`t WARNING: AD computer enumeration failed"
}

try{
	$sw = [Diagnostics.Stopwatch]::StartNew()
    $Test = Get-MsolDevice -All -ErrorAction stop
	$sw.Stop()
	$Time = ($sw.Elapsed).Seconds
    write-host "O365 computer lookup sucessful - Full enumeration in $Time second(s)" -foregroundcolor green
	Write-log "`t`t SUCCESS: Azure Compter enumeration in $Time second(s)"
	
}
Catch{
	write-host "Unable to lookup computers in O365 - If O365 is used, check plugin and permissions" -foregroundcolor yellow
	Write-log "`t`t WARNING: Azure computer enumeration failed"
}


#Check Services
write-log "`t START: Checking Services"
Write-Host " "
Function CheckService{
	Param ([string]$Service)
	Process{
		try{
			$myService = Get-Service -Name $Service
			if ($myService.Status -eq 'Running'){
				Write-log "`t`t SUCCESS: $Service available"
				Write-Host "SUCCESS: $Service service is available on this machine" -foregroundcolor green
			}
			else{
				Write-log "`t`t WARNING: $Service not available"
				Write-Host "WARNING: $Service service not available on this machine" -foregroundcolor red
			}

		}	
		catch{
			Write-log "`t`t ERROR: $($_.Exception.Message)"
			write-log "$(Get-Date) - End Log Entry"
			break
		}
	}
}


write-host ""
Write-Host "Checking that Windows Remote Management services are available"
write-Host "--------------------------------------------------------------"
write-host ""
CheckService WinRM


#Testing Remote Management
write-log "`t START: Checking Remote Management"
$Computer = Read-Host -Prompt 'Enter the name of a computer you know is online'
$Credentials = Get-Credential -Message "Enter the credentials you would use to remotely connect to this computer"


Try{
	$Test = Test-WSMan -ComputerName $Computer -Credential $Credentials -Authentication Default -ErrorAction stop
	Write-log "`t`t SUCCESS: WinRM test to $computer"
	Write-Host "SUCCESS: WinRM test to $computer" -foregroundcolor green
}
Catch{
	Write-log "`t`t WARNING: WinRM testing failed"
	Write-Host "WARNING: WinRM testing failed for $Computer. Any 'get-local' scripts will likely fail." -foregroundcolor red
}

Try{
	$Test = Get-WMIObject -computername $Computer Win32_OperatingSystem -Credential $Credentials -ErrorAction stop
	Write-log "`t`t SUCCESS: Remote permssions sufficient on $computer"
	Write-Host "SUCCESS: Remote permssions sufficient on $computer" -foregroundcolor green
}
Catch{
	Write-log "`t`t WARNING: Remote permssions NOT sufficient on $computer"
	Write-Host "WARNING: Remote permssions NOT sufficient on $computer. Any 'get-local' scripts will likely fail." -foregroundcolor red
}


#Close
write-log "$(Get-Date) - END: $Script run"
write-host " "
write-host "PreCheck Complete - check logfile for details: $Log" -foregroundcolor yellow
