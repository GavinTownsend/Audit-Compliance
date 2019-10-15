<#
	.SYNOPSIS
		Checks local group membership on selected computers
	
	.NOTES
		Script Name:	get-LOCAL_GroupMembers.ps1
		Created By:		Gavin Townsend
		Date:			August 2019
		
	.DESCRIPTION
		The script performs the follow actions:
			- Makes a selection of computer objects (eg all Servers, selection of 100 computers)
			- Enumerates the members for important local groups (administrators, power users etc)
			- Checks if there are any disabled or deleted accounts
			- Exports list for review
			
		
	.EXAMPLE
			.\get-LOCAL_GroupMembers.ps1
			
			Update selection of $Computers as required
			
	.REQUIREMENTS
		Active Directory module
		WinRM enabled on target machines (for WMI)
		Local administrator on target machines
		
		NB. Some WMI scans do not work on all operating systems (particularly older ones)
		
	.AUDIT CRITERIA
		Complete a discovery scan of local group members
		
		Collect a good sized random sample from both Servers and Computers (ensure to rename output file, to avoid overwriting)
			
		Make a note of the following exceptions
			- Where Daily user accounts are members of privileged groups (eg Administrators)
		
	.VERSION HISTORY
		1.0		Aug 2019	Gavin Townsend		Original Build
		
#>
Try{$Domain = $(get-addomain).dnsroot}
Catch{$Domain = ""}

$Log = "C:\temp\Audit\$Domain Local Groups $(get-date -f yyyy-MM-dd).csv"


#$Computers = Get-ADComputer -Filter {OperatingSystem -LIKE "*server*" -AND Enabled -eq $TRUE} -Property Name  
$Computers = Get-ADComputer -Filter {OperatingSystem -NOTLIKE "*server*" -AND Enabled -eq $TRUE} -Property Name 
$Computers = Get-Random -InputObject $Computers -Count 100

$LocalGroups =@("Administrators","Remote Desktop Users","Power Users","Backup Operators")
$GroupData =@()
$BadADLogins = 0

foreach ($Computer in $Computers.name) {
	if(!(Test-Connection -Cn $Computer -BufferSize 16 -Count 1 -ea 0 -quiet)){
		write-host "WARNING: $Computer not accessible" -f yellow
	}
	else {
		try {
			$Computer = $Computer
			write-host "Working on $computer"
			foreach ($Group in $LocalGroups) {
						
				([adsi]"WinNT://$Computer/$Group,group").psbase.Invoke('Members') | ForEach-Object {
					$Member = $_.GetType().InvokeMember('Name', 'GetProperty', $null, $_, $null)
				
					#Check AD Status
					if (($Member -eq "administrator") -or ($Member -eq "INTERACTIVE")){
						$LoginEnabled = "Common Local Account"
					}
					elseif (($Member -eq "Authenticated Users") -or ($Member -eq "Domain Users") -or ($Member -eq "Administrators") -or ($Member -eq "Backup Operators")){
						$LoginEnabled = "Common Built in Group"
					}
					elseif ($Member -LIKE "S-1-5*"){
						$LoginEnabled = "Deleted Account"
						$BadADLogins++
					}
					else{
						Try{
							$ADUser = get-aduser $Member -properties enabled
							$LoginEnabled = $ADUser.enabled
							
							if($LoginEnabled -eq $FALSE){
								$BadADLogins++
							}
						}
						catch{
							$LoginEnabled = "Local Account"
							$BadADLogins++
						}
					}
						
					#List Groups and Members
					$GRPobj = New-Object PSobject
					$GRPobj | Add-Member -MemberType NoteProperty -name "Computer" -value $Computer
					$GRPobj | Add-Member -MemberType NoteProperty -name "Group" -value $Group
					$GRPobj | Add-Member -MemberType NoteProperty -name "Member" -value $Member
					$GRPobj | Add-Member -MemberType NoteProperty -name "AD Enabled" -value $LoginEnabled
					$GroupData += $GRPobj
				}			
			}
		}
		catch {
			Write-Warning $_
		}
	}
}
$GroupData = $GroupData | sort -Property "Server","Group","Member"
$GroupData | Export-Csv $Log -notype -Encoding UTF8
write-host ""
write-host "CSV Export Complete to $Log"
Write-Host "Bad AD Logins: $BadADLogins" -foregroundcolor yellow

