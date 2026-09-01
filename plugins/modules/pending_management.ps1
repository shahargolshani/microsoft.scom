#!powershell

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ..module_utils._SCOMPsSetupUtils



$spec = @{
    options = @{
        agent_name = @{ type = "str"; required = $false; default = $null }
        state = @{
            type = "str"
            required = $false
            default = "approve"
            choices = @("approve", "reject")
        }
        action_account_username = @{ type = "str"; required = $false; default = $null }
        action_account_password = @{ type = "str"; required = $false; default = $null; no_log = $true }
    }
    required_together = @(
        , @("action_account_username", "action_account_password")
    )
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$agent_name = $module.Params.agent_name
$state = $module.Params.state

Import-SCOMPsModule -module $module
Connect-SCOMManagementGroup -Module $module

# Only manual-approval requests can be approved or denied. Other pending action types
# (PushInstall, UpdateAgent, RepairAgent, ...) represent in-progress operations and are
# never actioned by this module.
$pending = @()
try {
    $pending = @(Get-SCOMPendingManagement -ErrorAction Stop | Where-Object {
            # Filter to manual-approval requests only. The AgentPendingActionType enum
            # serialises to its name ("ManualApproval") when cast to string; comparing
            # the name AND the underlying integer (0) covers both representations.
            $typeStr = [string]$_.AgentPendingActionType
            $typeStr -eq "ManualApproval" -or $typeStr -eq "0"
        })
}
catch {
    $module.FailJson("Failed to query SCOM pending management: $($_.Exception.Message)", $_)
}

if ($null -ne $agent_name) {
    $pending = @($pending | Where-Object { [string]$_.AgentName -eq $agent_name })
}

if ($pending.Count -eq 0) {
    # Nothing awaiting manual approval (matching the filter) - already in the desired state.
    $module.Result.changed = $false
    $module.Result.agents = @()
    $module.ExitJson()
}

$module.Result.changed = $true
$module.Result.agents = @($pending | ForEach-Object { [string]$_.AgentName })

if (-not $module.CheckMode) {
    try {
        if ($state -eq "approve") {
            $approve_arguments = @{
                PendingAction = $pending
                ErrorAction = "Stop"
            }
            if ($null -ne $module.Params.action_account_username) {
                $secure_password = ConvertTo-SecureString -String $module.Params.action_account_password -AsPlainText -Force
                $approve_arguments.ActionAccount = New-Object System.Management.Automation.PSCredential(
                    $module.Params.action_account_username, $secure_password
                )
            }
            Approve-SCOMPendingManagement @approve_arguments
        }
        else {
            Deny-SCOMPendingManagement -PendingAction $pending -ErrorAction Stop
        }
    }
    catch {
        $module.FailJson("Failed to $state SCOM pending management: $($_.Exception.Message)", $_)
    }
}

$module.ExitJson()
