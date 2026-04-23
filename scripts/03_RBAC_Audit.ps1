# EntraOps - Script 3: Azure RBAC Audit
# Lists all role assignments across subscription, flags elevated service principal access

Connect-AzAccount -UseDeviceAuthentication

# ---------- GET SUBSCRIPTION ----------
$subscription = Get-AzSubscription | Select-Object -First 1
Set-AzContext -SubscriptionId $subscription.Id
Write-Host "Connected to subscription: $($subscription.Name)"

# ---------- ALL ROLE ASSIGNMENTS ----------
function Get-AllRoleAssignments {
    $assignments = Get-AzRoleAssignment
    $results = @()
    foreach ($item in $assignments) {
        $results += [PSCustomObject]@{
            DisplayName    = $item.DisplayName
            SignInName     = $item.SignInName
            ObjectType     = $item.ObjectType
            Role           = $item.RoleDefinitionName
            Scope          = $item.Scope
            Flag           = ""
        }
    }
    return $results
}

# ---------- FLAG ELEVATED SERVICE PRINCIPALS ----------
function Get-ElevatedServicePrincipals {
    param ($assignments)
    $elevatedRoles = @("Owner", "Contributor")
    $flagged = $assignments | Where-Object {
        $_.ObjectType -eq "ServicePrincipal" -and $elevatedRoles -contains $_.Role
    }
    foreach ($item in $flagged) {
        $item.Flag = "Elevated SP access — review required"
    }
    return $flagged
}

# ---------- MAIN ----------
Write-Host "🔍 Fetching Azure RBAC role assignments..."
$allAssignments = Get-AllRoleAssignments
Write-Host "Total role assignments found: $($allAssignments.Count)"

$elevatedSPs = Get-ElevatedServicePrincipals -assignments $allAssignments
Write-Host "Elevated service principals flagged: $($elevatedSPs.Count)"

# Export all assignments
$allAssignments | Export-Csv -Path "$PSScriptRoot/../reports/RBAC_Audit_Report.csv" -NoTypeInformation
Write-Host "RBAC audit report exported to reports/RBAC_Audit_Report.csv"

# Export elevated SPs separately
if ($elevatedSPs.Count -gt 0) {
    $elevatedSPs | Export-Csv -Path "$PSScriptRoot/../reports/Elevated_SP_Access.csv" -NoTypeInformation
    Write-Host "Elevated SP report exported to reports/Elevated_SP_Access.csv"
}

Write-Host ""
Write-Host "--- SUMMARY ---"
Write-Host "Total role assignments        : $($allAssignments.Count)"
Write-Host "Elevated SP assignments       : $($elevatedSPs.Count)"
