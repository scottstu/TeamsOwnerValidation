<#

.SYNOPSIS
  Name: TeamsOwnwerValidation.1.0.ps1
  The purpose of this script is to report all teams, channels, and users in an environment


.DISCLAIMER:
  Copyright (c) Microsoft Corporation. All rights reserved. This
  script is made available to you without any express, implied or
  statutory warranty, not even the implied warranty of
  merchantability or fitness for a particular purpose, or the
  warranty of title or non-infringement. The entire risk of the
  use or the results from the use of this script remains with you.

.Requirements
- MicrosoftTeams PowerShell Module

- Exchange Online Remote PowerShell Module - follow this article ...

https://docs.microsoft.com/en-us/powershell/exchange/exchange-online/connect-to-exchange-online-powershell/mfa-connect-to-exchange-online-powershell?view=exchange-ps


  Authors: 
       Scott Stubberfield

.EXAMPLE
  .\TeamsOwnwerValidation.MFA.1.0.ps1


#>


#PUBLIC FUNCTION
function CheckTeamsLicense { 
  [cmdletbinding()]
  param (
      [Parameter(Mandatory=$true)]$UPN
  )

    $UserInfo = Get-MSOLUser -UserPrincipalName $UPN
  foreach($license in $UserInfo.Licenses)
   {
    
    if ($license.servicestatus|where {$_.serviceplan.servicename -like "TEAMS1"})
     {
      $TEAMS1=$license.servicestatus|where {$_.serviceplan.servicename -like "TEAMS1"}

      if ($TEAMS1.ProvisioningStatus -eq "Success") {
        write-host "Yeah we found a Teams license for $($UserInfo.DisplayName)"
        Return $true
        }
      else {
        write-host "Yeah we did not find a Teams license for $($UserInfo.DisplayName)"
        Return $false
        }      

      }
      
   }



}


    try
    {

    Import-Module MicrosoftTeams -ErrorAction Stop

    }
    catch
    {

    Start-Process -FilePath "powershell" -Verb runas -ArgumentList "Install-Module MicrosoftTeams -Force -AllowClobber;" -Wait 
    Import-Module MicrosoftTeams

    }



$allGroups = @()

# Connect to MS Online Ser
Connect-MSOLService

$Authcache = [Microsoft.IdentityModel.Clients.ActiveDirectory.TokenCache]::DefaultShared
($Authcache.readitems())[0].DisplayableId

$ConnectUPN = $(($Authcache.readitems())[0].DisplayableId)

	If (!(Get-Command Get-Mailbox -ea silentlycontinue))
	{
		Import-Module $((Get-ChildItem -Path $($env:LOCALAPPDATA + "\Apps\2.0\") -Filter Microsoft.Exchange.Management.ExoPowershellModule.dll -Recurse).FullName | ?{ $_ -notmatch "_none_" } | select -First 1)
		$EXOSession = New-ExoPSSession -UserPrincipalName $ConnectUPN
		Import-PSSession $EXOSession -AllowClobber
	}
	
Connect-MicrosoftTeams -AccountId $ConnectUPN

$allTeams = get-team

$outputPath = "TeamsOwnerValidation.csv"

$allInfo = @()

foreach($team in $allTeams)
{

$allOwners = @()


$ownerNames = ""
$InvalidOwnerCount = 0

$allOwners = Get-TeamUser -GroupId $($team.GroupId) -Role Owner 

foreach($owner in $allOwners)
{

  $LicenseValidation = CheckTeamsLicense -UPN $owner.User
  $Name = $owner.User
  if ($LicenseValidation -eq $false) {
    $InvalidOwnerCount++
    $Name = $owner.User + "(NOT LICENSED)"
  }
  $ownerNames += $Name + ","
}

#$allowners


$object = New-Object -TypeName PSObject

Add-Member -InputObject $object -MemberType NoteProperty -Name GroupId -Value $($team.GroupId)
Add-Member -InputObject $object -MemberType NoteProperty -Name TeamName -Value $($team.DisplayName)
Add-Member -InputObject $object -MemberType NoteProperty -Name Description -Value $($team.Description)
Add-Member -InputObject $object -MemberType NoteProperty -Name owners -Value $ownerNames
Add-Member -InputObject $object -MemberType NoteProperty -Name InvalidOwnerCount -Value $InvalidOwnerCount

$allInfo += $object

}


$allInfo | Export-Csv -path "$outputPath" -NoTypeInformation -Force

Remove-PSSession -Session $EXOSession
