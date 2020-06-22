<#
	.SYNOPSIS
		Securely test the quality of Active Directory Passwords against breached data lists
	
	.NOTES
		Script Name:	Test-ADPasswords.ps1
		Created By:	Gavin Townsend
		Date:		October 2019
		
	.DESCRIPTION
		The script performs the follow actions:
			- Creates an offline Active Directory database (ntds.dit file) and registry key
			- Compares hashes against a custom 'bad password list' and breached password dataset (https://haveibeenpwned.com/Passwords)
			- Generates a password quality report
			- Optionally; 
				- Send an email to users explaining thier password was found in a breached data list
				- Flags a password reset at next logon
			
		
	.EXAMPLE
			.\Test-ADPasswords.ps1
			
			
	.REQUIREMENTS
		1. Access and permissions to create an Active Directory backup 
			
			Typically on Domain Controller as a domain administrator. Ensure to give a heads-up to your security team!
			
		
		2. Local copy of the Pwned Passwords list - https://haveibeenpwned.com/Passwords
			
			Download "NTLM ordered by hash" and unzip locally (eg c:\audit\pwned-passwords-ntlm-ordered-by-hash-v5.txt)
			
			Pwnded Passwords V6 Download file is around 8GB (20GB unzipped) and contains 570+ million hashes

		
		3. DSInternals Framework - https://github.com/MichaelGrafnetter/DSInternals
			
			If using PowerShell v5 simply run:	Install-Module -Name DSInternals -Force
			
			Else follow "Offline Module Distribution" steps via link above
			
		
		4. Active Directory PowerShell plugin - https://docs.microsoft.com/en-us/powershell/module/addsadministration/?view=win10-ps
			
			Optional if sending emails and forcing password reset
		
		
		5. Ensure to update function variables as required
		
		
	.VERSION HISTORY
		1.0		Oct 2019	Gavin Townsend		Original Build
		1.1		Jun 2020	Gavin Townsend		Update to reference Pwned Passwords V6
		
#>

#Location of HIBP dictionary file and working directory
$AuditPath = "c:\audit"	 

#Enable functions as required
$CreateNTDS = $TRUE
$TestPasswords = $TRUE
$SendEmail = $FALSE
$ResetPassword = $FALSE


#Functions
#---------

Function Write-Both {
	Param ([string]$LogString)
	$LogFile = "$AuditPath\Audit.log"
	Add-content $Logfile -value $LogString
	Write-Host $LogString
}
Write-Both "$(Get-Date) - New script run from $Env:Computername by $env:username"


Function Create-NTDS{
	param(
		[Parameter(Mandatory = $true)][System.IO.FileInfo] $AuditPath
	)

	Begin{
		Write-Both "`t START: Function CreateNTDS"
	}
	process{
	
		Try{
			if ($CreateNTDS -eq $TRUE){
				ntdsutil "activate instance ntds" ifm "create Full $AuditPath" q q
				Write-Both "`t FINISH: Active Directory offline copy completed to $AuditPath"
			}
			else{
				Write-Both "`t CreateNTDS = FALSE (function skipped)"
			}
		}
		Catch{
			Write-Both "ERROR: $($_.Exception.Message)"
			break
		}
	}
	end{}
}


Function Test-Passwords{
	param(
		[Parameter(Mandatory = $true)][System.IO.FileInfo] $AuditPath
	)

	Begin{
		Write-Both "`t START: Function Test-Passwords"
	}
	process{	
		$Key = Get-BootKey -SystemHivePath "$AuditPath\registry\SYSTEM"
		$DB = "$AuditPath\Active Directory\ntds.dit"
		$Dictionary = "$AuditPath\pwned-passwords-ntlm-ordered-by-hash-v5.txt" 
		$Report = "$AuditPath\AD Password Quality Report $(get-date -f yyyy-MM-dd).txt"
		$BadPasswordList = @("Winter2020","Spring2019","Summer2019","Autumn2020","Password123!","Password","12345678","Pa$$w0rd","qwertyuiop") 
		$OU = "*OU=Users,DC=MyDomain,DC=com"  # <- Ensure to include the wildcard

		Try{
			if ($TestPasswords -eq $TRUE){
				$Results = Get-ADDBAccount -All -DBPath $DB -BootKey $Key | `
				where DistinguishedName -like $OU | `
				Test-PasswordQuality -WeakPasswords $BadPasswordList -WeakPasswordHashesFile $Dictionary
				
				$Results | Out-File $Report
				Write-Both "`t FINISH: Report saved to $Report" 
				Invoke-Item $Report
			}
			else{
				Write-Both "`t TestPasswords = FALSE (function skipped)"
			}
		}
		Catch{
			Write-Both "ERROR: $($_.Exception.Message)"
			break
		}
	}
	end{
		Return $Results
	}
}


Function Send-Email{
	Param (
		[string]$MailBody,
		[string]$To
	)
	
	process{	
		$SMTPServer = "smtp.mydomain.com"
		$From = "infosec@mydomain.com"

		Try{
			if ($SendEmail -eq $TRUE){
				Send-MailMessage -To $To -From $From -Subject "Password Audit" -SmtpServer $SMTPServer -body $MailBody -BodyAsHtml
				Write-Both "`t Email sent to $To"
			}
			else{
				Write-Both "`t Send Email = FALSE (email would have gone to $To)"
			}
		}
		Catch{
			Write-Both "ERROR: $($_.Exception.Message)"
			break
		}
	}
	end{}
}


Function Reset-Password{
	param(
		[string]$Account
	)

	process{	
		Try{
			if ($ResetPassword -eq $TRUE){
				Get-ADUser -Identity $Account | Set-ADUser CannotChangePassword:$FALSE -PasswordNeverExpires:$FALSE -ChangePasswordAtLogon:$TRUE
				Write-Both "`t Password reset flagged for $Account"
			}
			else{
				Write-Both "`t Reset Password = FALSE (password reset would have been flagged for $Account)"
			}
		}
		Catch{
			Write-Both "ERROR: $($_.Exception.Message)"
			break
		}
	}
	end{}
}


#Runtime
#-------

#AD Backup
Create-NTDS $AuditPath

#Password Audit
Test-Passwords $AuditPath
$BreachAccounts = $Results.WeakPassword

#Send email
Write-Both "`t START: Function Sending Emails"

$MailBody = "In accordance with recommended best practice, the Information Security Team audits the quality of our login passwords against breached data lists.</br>
During a recent audit, your computer login password was found in a blocklist or the <a href='https://haveibeenpwned.com/Passwords'>Pwned Passwords dataset</a>.</br>
</br>
<b>What does this mean?</b></br>
Passwords that are found in breached data are what we call 'known bad'. That is, these passwords have been exposed on the internet and represent a risk to those using them.</br>
</br>
Whilst it may be a coincidence, passwords are typically on the list because:</br>
   - You have re-used the same password elsewhere (and that service was compromised in the past).</br>
   - You are using a weak password which is commonly used by other people.</br>
</br>
<b>What do I need to do?</b></br>
Your password must be changed as soon as possible</br>
Make sure your password is long, unique and random. Here is a short (3min) video on some <a href='https://youtu.be/Nl-VA9w9cZk'>good and bad password habits</a>.</br>
</br>
NB. We do not know your password. The audit is conducted securely by our Information Security team, by comparing offline 'hash files'.	</br> 
If you have any questions, please contact your local IT Service Desk.</br>
</br>
Regards </br>
Information Security</br>"


foreach($Account in $BreachAccounts){
	Try{
		$ADUser = Get-ADUser -Identity $Account -Properties mail
		$To = $ADUser.mail
		Send-Email $MailBody $To
	}
	Catch{
		Write-Both "ERROR: $($_.Exception.Message)"
	}
}


#Reset Password 
Write-Both "`t START: Function Reset-Password"

foreach($Account in $BreachAccounts){
	Reset-Password $Account
}
