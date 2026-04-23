# EntraOps - Script 1: JML Lifecycle Automation
# Automates Joiner and Leaver workflows in Microsoft Entra ID

Connect-MgGraph -Scopes "User.ReadWrite.All","Group.ReadWrite.All","GroupMember.ReadWrite.All" -NoWelcome

# ---------- JOINER ----------
function New-Joiner {
    param (
        [string]$DisplayName,
        [string]$UPN,
        [string]$GroupId
    )

    $user = New-MgUser `
        -DisplayName $DisplayName `
        -UserPrincipalName $UPN `
        -AccountEnabled:$true `
        -PasswordProfile @{
            Password = "TempPass@1234"
            ForceChangePasswordNextSignIn = $true
        } `
        -MailNickname ($UPN.Split("@")[0])

    Write-Host "✅ User created: $($user.DisplayName) | $($user.Id)"

    $body = @{ "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($user.Id)" }
    Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/groups/$GroupId/members/`$ref" -Body $body
    Write-Host "✅ Added to group: $GroupId"
}

# ---------- LEAVER ----------
function Remove-Leaver {
    param (
        [string]$UPN
    )

    $user = Get-MgUser -Filter "userPrincipalName eq '$UPN'"

    if (-not $user) {
        Write-Host "❌ User not found: $UPN"
        return
    }

    Update-MgUser -UserId $user.Id -AccountEnabled:$false
    Write-Host "✅ Account disabled: $($user.DisplayName)"

    $groups = Get-MgUserMemberOf -UserId $user.Id
    foreach ($group in $groups) {
        try {
            Remove-MgGroupMemberByRef -GroupId $group.Id -DirectoryObjectId $user.Id
            Write-Host "✅ Removed from group: $($group.Id)"
        } catch {
            Write-Host "⚠️ Skipped group $($group.Id): $_"
        }
    }

    Write-Host "✅ Leaver process complete for $($user.DisplayName)"
}

# ---------- EXPORT REPORT ----------
function Export-UserReport {
    $users = Get-MgUser -All -Property "DisplayName,UserPrincipalName,AccountEnabled,CreatedDateTime"
    $users | ForEach-Object {
        [PSCustomObject]@{
            DisplayName    = $_.DisplayName
            UPN            = $_.UserPrincipalName
            AccountEnabled = $_.AccountEnabled
            CreatedDate    = $_.CreatedDateTime
        }
    } | Export-Csv -Path "$PSScriptRoot/../reports/JML_User_Report.csv" -NoTypeInformation

    Write-Host "✅ User report exported to reports/JML_User_Report.csv"
}

# ---------- MAIN ----------
$testGroupId = "c20ff191-b33a-40b7-a469-e83ca15ff330"

# Run Joiner
New-Joiner -DisplayName "Test Joiner 2" -UPN "testjoiner2@notazure.onmicrosoft.com" -GroupId $testGroupId

# Export report
Export-UserReport

# Run Leaver (uncomment after Joiner works):
# Remove-Leaver -UPN "testjoiner2@notazure.onmicrosoft.com"