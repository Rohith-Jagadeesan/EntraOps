# EntraOps - Script 4: Identity Hygiene Report
# Detects stale accounts, users without MFA, and permanent privileged role assignments

Connect-MgGraph -Scopes "User.Read.All","AuditLog.Read.All","UserAuthenticationMethod.Read.All","RoleManagement.Read.All" -NoWelcome

# ---------- STALE ACCOUNTS ----------
function Get-StaleAccounts {
    $90DaysAgo = (Get-Date).AddDays(-90)
    $results = @()

    $users = Get-MgUser -All -Property "DisplayName,UserPrincipalName,AccountEnabled,SignInActivity"

    foreach ($user in $users) {
        $lastSignIn = $user.SignInActivity.LastSignInDateTime
        if ($null -eq $lastSignIn -or $lastSignIn -lt $90DaysAgo) {
            $results += [PSCustomObject]@{
                DisplayName  = $user.DisplayName
                UPN          = $user.UserPrincipalName
                LastSignIn   = if ($lastSignIn) { $lastSignIn } else { "Never" }
                AccountEnabled = $user.AccountEnabled
                Flag         = "⚠️ Stale — no sign-in for 90+ days"
            }
        }
    }
    return $results
}

# ---------- USERS WITHOUT MFA ----------
function Get-UsersWithoutMFA {
    $results = @()
    try {
        $mfaReport = Get-MgReportAuthenticationMethodUserRegistrationDetail -All
        $noMFA = $mfaReport | Where-Object { $_.IsMfaRegistered -eq $false }

        foreach ($user in $noMFA) {
            $results += [PSCustomObject]@{
                DisplayName   = $user.UserDisplayName
                UPN           = $user.UserPrincipalName
                MFARegistered = $false
                Flag          = "⚠️ No MFA registered"
            }
        }
    } catch {
        Write-Host "⚠️ Could not fetch MFA report: $_"
    }
    return $results
}

# ---------- PERMANENT PRIVILEGED ROLES ----------
function Get-PermanentPrivilegedRoles {
    $results = @()
    try {
        $assignments = Get-MgRoleManagementDirectoryRoleAssignment -All
        foreach ($item in $assignments) {
            try {
                $user = Get-MgUser -UserId $item.PrincipalId -ErrorAction Stop
                $role = Get-MgRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $item.RoleDefinitionId
                $results += [PSCustomObject]@{
                    DisplayName = $user.DisplayName
                    UPN         = $user.UserPrincipalName
                    Role        = $role.DisplayName
                    Flag        = "⚠️ Permanent privileged role — convert to PIM eligible"
                }
            } catch {
                # Skip service principals
            }
        }
    } catch {
        Write-Host "⚠️ Could not fetch role assignments: $_"
    }
    return $results
}

# ---------- MAIN ----------
Write-Host "🔍 Running identity hygiene checks..."

$staleAccounts   = Get-StaleAccounts
$noMFAUsers      = Get-UsersWithoutMFA
$permanentRoles  = Get-PermanentPrivilegedRoles

Write-Host "✅ Stale accounts found           : $($staleAccounts.Count)"
Write-Host "✅ Users without MFA              : $($noMFAUsers.Count)"
Write-Host "✅ Permanent privileged roles     : $($permanentRoles.Count)"

# Export reports
if ($staleAccounts.Count -gt 0) {
    $staleAccounts | Export-Csv -Path "$PSScriptRoot/../reports/Stale_Accounts.csv" -NoTypeInformation
    Write-Host "✅ Stale accounts exported to reports/Stale_Accounts.csv"
}

if ($noMFAUsers.Count -gt 0) {
    $noMFAUsers | Export-Csv -Path "$PSScriptRoot/../reports/No_MFA_Users.csv" -NoTypeInformation
    Write-Host "✅ No MFA users exported to reports/No_MFA_Users.csv"
}

if ($permanentRoles.Count -gt 0) {
    $permanentRoles | Export-Csv -Path "$PSScriptRoot/../reports/Permanent_Privileged_Roles.csv" -NoTypeInformation
    Write-Host "✅ Permanent roles exported to reports/Permanent_Privileged_Roles.csv"
}

# Summary report
$summary = [PSCustomObject]@{
    StaleAccounts          = $staleAccounts.Count
    UsersWithoutMFA        = $noMFAUsers.Count
    PermanentPrivilegedRoles = $permanentRoles.Count
    GeneratedOn            = Get-Date
}
$summary | Export-Csv -Path "$PSScriptRoot/../reports/Hygiene_Summary.csv" -NoTypeInformation

Write-Host ""
Write-Host "--- HYGIENE SUMMARY ---"
Write-Host "Stale accounts (90+ days)     : $($staleAccounts.Count)"
Write-Host "Users without MFA             : $($noMFAUsers.Count)"
Write-Host "Permanent privileged roles    : $($permanentRoles.Count)"
Write-Host "✅ Full summary exported to reports/Hygiene_Summary.csv"