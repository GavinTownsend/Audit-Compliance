<#
	.SYNOPSIS
		Identify which accounts have Active Directory Extended Rights
	
	.NOTES
		Name:	get-AD_ExtendedRightsAudit.ps1
		Author: Gavin Townsend
		Date:	November 2019
#>

$DSE = [ADSI]"LDAP://Rootdse"
$Entries = ([ADSI]("LDAP://" + $DSE.defaultNamingContext),[ADSI]("LDAP://" + $DSE.configurationNamingContext))
$Rights = ([ADSI]("LDAP://CN=Extended-Rights," + $DSE.ConfigurationNamingContext)).psbase.Children

foreach($Entry in $Entries){
	foreach($Right in $Rights){
		$Permissions = $Entry.psbase.ObjectSecurity.Access | ? { $_.ObjectType -eq [GUID]$Right.RightsGuid.Value }
		foreach($Permissions in $Permissions){
			write-host $Entry.distinguishedName `t $Right.displayname `t $Permissions.IdentityReference 
		}
	}
}
