# EntraOps — Entra ID IAM Automation Toolkit

A PowerShell-based automation toolkit targeting common BAU (day-to-day operational) tasks in Microsoft Entra ID enterprise environments. Built as a hands-on lab project to simulate real-world L3 IAM operational workflows.

## Problem Statement

Enterprise Entra ID environments accumulate identity risk over time — stale accounts, permanent privileged role assignments, users without MFA, and unaudited Azure RBAC access. This toolkit automates the detection and reporting of these issues, reducing reliance on manual periodic audits.

## Scripts

### 01_JML_Lifecycle.ps1
Automates Joiner-Mover-Leaver workflows in Entra ID.
- Creates new users and assigns them to security groups (Joiner)
- Disables accounts and removes all group memberships on offboarding (Leaver)
- Exports a full user report to CSV
- **Tech:** Microsoft Graph API, PowerShell, `New-MgUser`, `Invoke-MgGraphRequest`

### 02_PIM_Audit.ps1
Audits Privileged Identity Management role assignments.
- Queries all PIM-eligible role assignments
- Identifies permanent role assignments that should be converted to PIM-eligible (just-in-time)
- Flags Global Admin and other privileged roles assigned permanently
- Exports findings to CSV
- **Tech:** Microsoft Graph API, `Get-MgRoleManagementDirectoryRoleAssignment`

### 03_RBAC_Audit.ps1
Audits Azure RBAC role assignments across subscriptions.
- Lists all role assignments at subscription scope
- Flags service principals with Owner or Contributor access
- Exports full assignment report and elevated SP report separately
- **Tech:** Az PowerShell module, `Get-AzRoleAssignment`

### 04_Identity_Hygiene.ps1
Runs proactive identity hygiene checks across the tenant.
- Detects stale accounts with no sign-in activity for 90+ days
- Identifies users without MFA registered
- Flags permanent privileged role assignments for PIM review
- Exports individual and summary reports to CSV
- **Tech:** Microsoft Graph API, `Get-MgUser`, `Get-MgReportAuthenticationMethodUserRegistrationDetail`

## Prerequisites

- PowerShell 7+
- Microsoft.Graph module: `Install-Module Microsoft.Graph`
- Az module: `Install-Module Az`
- Microsoft Entra ID P2 license (for PIM features)
- Azure subscription (for RBAC audit)

## Setup

```powershell
# Clone the repo
git clone https://github.com/Rohith-Jagadeesan/EntraOps.git
cd EntraOps

# Install modules
Install-Module Microsoft.Graph -Scope CurrentUser
Install-Module Az -Scope CurrentUser

# Run any script
pwsh scripts/01_JML_Lifecycle.ps1
```

## Output

Each script exports CSV reports to the `/reports` directory. Reports are excluded from version control via `.gitignore` to prevent real identity data from being pushed to GitHub.

| Report | Script | Contents |
|---|---|---|
| JML_User_Report.csv | Script 1 | All users with account status |
| PIM_Audit_Report.csv | Script 2 | Eligible and permanent role assignments |
| RBAC_Audit_Report.csv | Script 3 | All Azure subscription role assignments |
| Elevated_SP_Access.csv | Script 3 | Service principals with elevated access |
| Stale_Accounts.csv | Script 4 | Users inactive for 90+ days |
| Permanent_Privileged_Roles.csv | Script 4 | Permanent privileged roles flagged for PIM |
| Hygiene_Summary.csv | Script 4 | Consolidated hygiene findings |

## Notes

This toolkit was built in a personal Azure lab tenant for hands-on learning purposes. It targets real BAU operational use cases aligned to enterprise Entra ID L3 IAM support scenarios.
