<#
	.SYNOPSIS
		Reports on a the Active Directory domain configuration.
	
	.NOTES
		Script Name:	get-AD_Discovery.ps1
		Created By:		Gavin Townsend
		Date:			August 2019
	
	.DESCRIPTION
		This script will perform the following actions:
			- Writes outputs to the console.
				- Also creates a transcript output in your Documents folder.
			- Gets forest and domain information.
			- Gets forest and domain functional levels.
			- Gets domain creation date.
			- Gets FSMO role holders.
			- Gets AD schema version.
			- Gets tombstone lifetime.
			- Gets domain password policy.
			- Gets AD backup information.
			- Checks to see if AD Recycle Bin is enabled.
			- Gets AD Sites and Subnets.
			- Gets AD Site replication links.
			- Gets AD trust information.
			- Gets users and groups information.
				- Number of users
				- Number of groups
				- Inactive accounts based on 30, 60, 90 days.
			- Lists OUs with blocked inheritance.
			- Lists unlinked GPOs.
			- Lists duplicate SPNs.
			
	.AUDIT CRITERIA
		Complete a discovery scan of the AD enviornment
			- Data gathered is informational to assist the audit scope
			
		Note any Warnings

	.EXAMPLE
		.\get-AD_Discovery.ps1

	.REQUIREMENTS
		Active Directory module
		PS v4 or later (server 2012R2)
		
	.VERSION HISTORY
		1.0		June 2019	Gavin Townsend		Original Build
		
#>

# Global variables 
	$date = Get-Date 
	$fDate = Get-Date -UFormat "%m%d%Y-%H%M" 
	$rDSE = Get-ADRootDSE 
	$dInfo = Get-ADDomain 
	$fInfo = Get-ADForest 

$Domain = $(get-addomain).dnsroot
$Log = "C:\Temp\Audit\$Domain AD Discovery $(get-date -f yyyy-MM-dd).txt"
	
Start-Transcript -path $Log 
 
Write-Host "" 
 
	Write-Host "Date/time stamp:" $date 
 
Write-Host "" 
# 
# 
# Forest/Domain information 
	Write-host "Domain Information:" -ForegroundColor Green 
	Write-Host "Domain Name:" $dInfo.dnsroot 
	Write-Host "NetBIOS Name:" $dInfo.netbiosname 
 
# Forest/Domain Functional Levels 
	$ffl = ($fInfo).forestmode 
	$dfl = ($dInfo).domainmode 
	$dAge = Get-ADObject ($rDSE).rootDomainNamingContext -Property whencreated 
		Write-Host "Forest Funcational Level:" $ffl	 
		Write-Host "Domain Functional Level:" $dfl 
		Write-Host "Domain created:" $dAge.whencreated 
 
Write-Host "" 
 
# FSMO holders 
	Write-Host "FSMO Role Holders:" -ForegroundColor Green 
		$fInfo | Select-Object DomainNamingMaster, SchemaMaster | FT -AutoSize 
		$dInfo | Select-Object InfrastructureMaster, RIDMaster, PDCEmulator | FT -AutoSize 
 
# Schema version 
	$schema = Get-ADObject ($rDSE).schemaNamingContext -Property objectVersion 
	$sVersion = $schema.objectVersion 
		If ($schema.objectVersion -eq 47) { Write-Host "Schemea Version:" -NoNewline; Write-Host " 47 - Server 2008 R2" -ForegroundColor Yellow }
		ElseIf ($schema.objectVersion -eq 56) { Write-Host "Schemea Version:" -NoNewline; Write-Host " 56 - Server 2012" -ForegroundColor Yellow }
		ElseIf ($schema.objectVersion -eq 69) { Write-Host "Schemea Version:" -NoNewline; Write-Host "	69 - Server 2012 R2" -ForegroundColor Green }
		ElseIf ($schema.objectVersion -eq 87) { Write-Host "Schemea Version:" -NoNewline; Write-Host "	87 - Server 2016" -ForegroundColor Green }
		Else {Write-Host "WARNING: Schema version is 2008 or lower" -ForegroundColor Red} 
 
Write-Host "" 
 
# Tombstone lifetime 
	$ts = (Get-ADObject -Identity "CN=Directory Service,CN=Windows NT,CN=Services,$(($rDSE).configurationNamingContext)" -Properties tombstoneLifetime).tombstoneLifetime 
		Write-Host "Tombstone Lifetime:" $ts 
 
Write-Host "" 
 
# Domain password policy 
	Write-Host "Domain password policy:" -ForegroundColor Green 
		$dPwd = Get-ADDefaultDomainPasswordPolicy  
		$dPwd | Select-Object ComplexityEnabled, LockoutDuration, LockoutThreshold, MaxPasswordAge, ` 
				MinPasswordAge, MinPasswordLength, PasswordHistoryCount, ReversibleEncryptionEnabled, LockoutObservationWindow | Fl 
 
# AD backups				  
	Write-Host "AD Backups:" -ForegroundColor Green 
		repadmin /showbackup $dInfo.dnsroot 
 
Write-Host "" 
 
# AD recycle bin 
	$adRB = (Get-ADOptionalFeature 'Recycle Bin Feature').enabledscopes 
	 if ($adRB -ne $null) 
			{Write-Host "AD Recycle Bin is ENABLED." -ForegroundColor Green} 
	  else 
			{Write-Host "WARNING: AD Recycle Bin is NOT ENABLED!!" -ForegroundColor Red} 
 
Write-Host "" 
 
# AD Sites and Subnets 
	Write-Host "AD Sites and Subnets:" -ForegroundColor Green 
		$FormatEnumerationLimit=-1 
		$sites = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest().Sites 
 
		$sitesubnets = @()	
			foreach ($site in $sites) 
			{ 
				   foreach ($subnet in $site.subnets){ 
					  $obj = New-Object PSCustomObject -Property @{ 
					  'Site' = $site.Name 
					  'Subnet' = $subnet; 
					  'Server' =$site.servers  ; } 
					  $sitesubnets += $obj	
				   } 
			} 
 
			$sitesubnets | Ft -AutoSize -Wrap 
   
 Write-Host ""	 
 
# AD replication links 
	Write-Host "AD relplication links:" -ForegroundColor Green 
		Get-ADReplicationSiteLink -Filter * -Properties ReplInterval,Options | FT Name,Cost,ReplInterval,Options,SitesIncluded -AutoSize -Wrap 
 
# AD trusts 
	Write-Host "Active Directory Trusts:" -ForegroundColor Green 
		Get-ADTrust -Filter * -Properties SelectiveAuthentication | FT Name,Direction,ForestTransitive,IntraForest,SelectiveAuthentication -AutoSize -Wrap 
 
Write-Host "" 
 
# AD users/groups  
	Write-Host "Domain groups and their member counts, including counts from nested groups" -ForegroundColor Green 
   
Write-Host "" 
Write-Host "The following actions may take several minutes to complete..." -ForegroundColor Yellow	
Write-Host "" 
 
# AD users/groups 
	Write-Host "Domain objects:" -ForegroundColor Green 
		$users = Get-ADuser -Filter * -Properties name,lastlogondate,enabled 
		$uCount = ($users).count 
		$eUsers = ($users | where {$_.enabled -eq "True"}).count 
		$Groups = (Get-ADgroup -Filter *).count 
			Write-Host "Total # of user obj:" $uCount 
			Write-Host "Enabled user obj:" $eUsers 
			Write-Host "Total # of groups:" $Groups 
 
Write-Host "" 
 
	Write-Host "Stale user objects (Enabled accounts that haven't logged in within X days):" -ForegroundColor Green 
		$30Days = ($date).Adddays(-(30)) 
		$60Days = ($date).Adddays(-(60)) 
		$90Days = ($date).Adddays(-(90)) 
		$30 = ($users | where {$_.lastlogondate -lt $30Days -and $_.enabled -eq $true}).count 
		$60 = ($users | where {$_.lastlogondate -lt $60Days -and $_.enabled -eq $true}).count 
		$90 = ($users | where {$_.lastlogondate -lt $90Days -and $_.enabled -eq $true}).count 
			Write-Host "30+ days Inactive:" $30 
			Write-Host "60+ days Inactive:" $60 
			Write-Host "90+ days Inactive:" $90 
 
Write-Host "" 
 
# OUs with blocked inheritance 
	Write-Host "List of OUs with Blocked Inheritance:" -ForegroundColor Green 
	try{
		Get-ADOrganizationalUnit -SearchBase $rDSE.defaultNamingContext -Filter * | Where-Object {(Get-GPInheritance $_.DistinguishedName).GpoInheritanceBlocked -eq "Yes"} | Sort-Object Name | ft Name,DistinguishedName -AutoSize -Wrap 
	}
	Catch{
		Write-Host "WARNING: GPO cmdlets unavailable (module not loaded or user may not have permission" -foregroundcolor yellow
	}
	
Write-Host "" 
 
# Unlinked GPOs 
	Write-Host "List of GPOs currently not linked:" -ForegroundColor Green 
	
	try{
		Get-GPO -All |	
			foreach{  
			   If ($_ | Get-GPOReport -ReportType XML | Select-String -NotMatch "<LinksTo>") 
				{ 
				   Write-Host $_.DisplayName 
				} 
			} 
	}
	Catch{
		Write-Host "WARNING: GPO cmdlets unavailable (module not loaded or user may not have permission" -foregroundcolor yellow
	}

Write-Host "" 
 
# Duplicate SPNs 
	$dSPN = setspn -x -f -p 
		Write-Host "Duplicate SPNs:" -ForegroundColor Green 
		$dSPN 
 
Stop-Transcript 
 
Write-Host "Domain Discovery Complete." -ForegroundColor Gray -BackgroundColor DarkGreen
