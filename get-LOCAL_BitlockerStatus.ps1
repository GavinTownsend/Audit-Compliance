<#
	.SYNOPSIS
		Gets the bitlocker status for a list of computers
	
	.NOTES
		Script Name:	get-LOCAL_BitlockerStatus.ps1
		Created By:		Gavin Townsend
		Date:			August 2019
		
	.DESCRIPTION
		The script performs the follow actions:
			- Gets a random list of computers
			- Collects the BitLocker status for c: drive	
			
		Drive Types
			0	DRIVE_UNKNOWN
			1	DRIVE_NO_ROOT_DIR
			2	DRIVE_REMOVABLE
			3	DRIVE_FIXED
			4	DRIVE_REMOTE
			5	DRIVE_CDROM
			6	DRIVE_RAMDISK
		
	.EXAMPLE
			.\get-LOCAL_BitlockerStatus.ps1
			
	.REQUIREMENTS
		Active Directory module
		WinRM enabled on target machines (for WMI)
		Local administrator on target machines
		
		NB. Some WMI scans do not work on all operating systems (particularly older ones)
		
	.AUDIT CRITERIA
		Complete a discovery scan of Bitlocker statuses
			
		Make a note of the following exceptions
			- Where the protection status is off
			- Where the encryption status is NOT 'FullyEncrypted'
				
	.VERSION HISTORY
		1.0		Aug 2019	Gavin Townsend		Original Build
		
#>


$Domain = $(get-addomain).dnsroot
$Log = "C:\temp\Audit\$Domain Bitlocker Status $(get-date -f yyyy-MM-dd).csv"

$Computers = Get-ADComputer -Filter {OperatingSystem -NOTLIKE "*server*" -AND Enabled -eq $TRUE} -Property Name
$Computers = Get-Random -InputObject $Computers -Count 100

$DriveType = "3"
$DriveLetter = "C:"
$obj=@()
$Data = @()

$OnCount = 0
$UnknownCount = 0
$OffCount = 0

foreach ($Computer in $Computers.name) {

	try{
		write-host "Working on $Computer"

		$LocalDrives = Get-CimInstance -Namespace 'root\CIMV2' -ClassName 'CIM_LogicalDisk' -ComputerName $Computer -ErrorAction 'stop' | `
			Where-Object -Property 'DriveType' -in $DriveType
		$ComputerCount++
		
		Get-CimInstance	 -Namespace 'root\CIMV2\Security\MicrosoftVolumeEncryption' -ClassName 'Win32_EncryptableVolume' -ComputerName $Computer -ErrorAction 'stop' | `
			Where-Object -Property 'DriveLetter' -in $($LocalDrives.DeviceID) | `
			ForEach-Object {

			#  Get the drive type
			$GetDriveType = $($LocalDrives | Where-Object -Property 'DeviceID' -eq $($_.DriveLetter)) | Select-Object -ExpandProperty 'DriveType'

			#  Create the Result Props and make the ProtectionStatus more report friendly
			$ResultProps = [ordered]@{
				'Drive'			   = $($_.DriveLetter)
				'ProtectionStatus' = $(
					Switch ($_.ProtectionStatus) {
						0 { 'OFF' }
						1 { 'ON' }
						2 { 'UNKNOWN' }
					}
				)
				'EncryptionStatus' = $(
					Switch ($_.ConversionStatus) {
						0 { 'FullyDecrypted' }
						1 { 'FullyEncrypted' }
						2 { 'EncryptionInProgress' }
						3 { 'DecryptionInProgress' }
						4 { 'EncryptionPaused' }
						5 { 'DecryptionPaused' }
					}
				)
				'DriveType' = $GetDriveType
			}
		
			$obj = New-Object -TypeName PSObject
			$obj | Add-Member -MemberType NoteProperty -Name "Computer" -Value $Computer
			$obj | Add-Member -MemberType NoteProperty -Name "Drive" -Value $ResultProps.Drive
			$obj | Add-Member -MemberType NoteProperty -Name "Type" -Value $ResultProps.DriveType
			$obj | Add-Member -MemberType NoteProperty -Name "Protection" -Value $ResultProps.ProtectionStatus
			$obj | Add-Member -MemberType NoteProperty -Name "Encryption" -Value $ResultProps.EncryptionStatus
		
			$Data += $obj
			
			$DriveCount++
			if ($ResultProps.ProtectionStatus -eq 'OFF'){
				$OffCount++
			}
			elseif ($ResultProps.ProtectionStatus -eq 'ON'){
				$OnCount++
			}
			elseif ($ResultProps.ProtectionStatus -eq 'UNKNOWN'){
				$UnknownCount++
			}
		}
	}

	Catch {
		write-host "WARNING: $Computer not accessible" -foregroundcolor yellow
	}
}

$Data | sort-object -property Computer,Drive | Export-Csv $Log -notype

write-host ""
write-host "There were $DriveCount drives listed from $ComputerCount computers"
write-host "Protection is on: $OnCount"
write-host "Protection is unknown: $UnknownCount" -foregroundcolor yellow
write-host "Protection is off: $OffCount" -foregroundcolor red
write-host ""
write-host "Log Export Complete to $Log" 
