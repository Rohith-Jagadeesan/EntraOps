# EntraOps - Script 2: PIM Role Eligibility Audit
# Queries PIM eligible and permanent role assignments, flags permanent ones for review

Connect-MgGraph -Scopes "RoleManagement.Read.All","Directory.Read.All" -NoWelcome

# ---------- HELPER: Get display name for a principal ----------
function Get-PrincipalName {
    param ([string]$PrincipalId)
    try {
        $user = Get-MgUser -UserId $PrincipalId -ErrorAction Stop
        return $user.DisplayName
    } catch {
        try {
            $sp = Get-MgServicePrincipal -ServicePrincipalId $PrincipalId -ErrorAction Stop
            return $sp.DisplayName
        } catch {
            return $PrincipalId
        }
    }
}

# ---------- ELIGIBLE ROLES ----------
function Get-EligibleRoles {
    $results = @()
    try {
        $eligible = Get-MgRoleManagementDirectoryRoleEligibilitySchedule -All
        foreach ($item in $eligible) {
            $principalName = Get-PrincipalName -PrincipalId $item.PrincipalId
            $roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $item.RoleDefinitionId
            $results += [PSCustomObject]@{
                PrincipalName  = $principalName
                RoleName       = $roleDefinition.DisplayName
                AssignmentType = "Eligible (PIM)"
                EndDate        = $item.ScheduleInfo.Expiration.EndDateTime
                Status         = "JIT Eligible"
            }
        }
    } catch {
        Write-Host "⚠️ Could not fetch eligible roles: $_"
    }
    return $results
}

# ---------- PERMANENT ROLES ----------
function Get-PermanentRoles {
    $results = @()
    try {
        $permanent = Get-MgRoleManagementDirectoryRoleAssignment -All
        foreach ($item in $permanent) {
            $principalName = Get-PrincipalName -PrincipalId $item.PrincipalId
            $roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $item.RoleDefinitionId
            $results += [PSCustomObject]@{
                PrincipalName  = $principalName
                RoleName       = $roleDefinition.DisplayName
                AssignmentType = "Permanent"
                EndDate        = "Never"
                Status         = "⚠️ Review for PIM eligibility"
            }
        }
    } catch {
        Write-Host "⚠️ Could not fetch permanent roles: $_"
    }
    return $results
}

# ---------- MAIN ----------
Write-Host "🔍 Fetching PIM role assignments..."

$eligibleRoles  = Get-EligibleRoles
$permanentRoles = Get-PermanentRoles

Write-Host "✅ Eligible (PIM) roles found : $($eligibleRoles.Count)"
Write-Host "✅ Permanent roles found       : $($permanentRoles.Count)"

$allRoles = @()
$allRoles += $eligibleRoles
$allRoles += $permanentRoles

if ($allRoles.Count -gt 0) {
    $allRoles | Export-Csv -Path "$PSScriptRoot/../reports/PIM_Audit_Report.csv" -NoTypeInformation
    Write-Host "✅ PIM audit report exported to reports/PIM_Audit_Report.csv"
} else {
    Write-Host "⚠️ No role data found — check permissions or assign a PIM eligible role first"
}

Write-Host ""
Write-Host "--- SUMMARY ---"
Write-Host "Eligible (PIM) assignments : $($eligibleRoles.Count)"
Write-Host "Permanent assignments       : $($permanentRoles.Count)"
Write-Host "Flagged for PIM review      : $($permanentRoles.Count)"