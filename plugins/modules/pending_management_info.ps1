#!powershell

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ..module_utils._SCOMPsSetupUtils



$spec = @{
    options = @{
        agent_name = @{ type = "str"; required = $false; default = $null }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$agent_name = $module.Params.agent_name

Import-SCOMPsModule -module $module
Connect-SCOMManagementGroup -Module $module

$pending = @()
try {
    $pending = @(Get-SCOMPendingManagement -ErrorAction Stop)
}
catch {
    $module.FailJson("Failed to query SCOM pending management: $($_.Exception.Message)", $_)
}

if ($null -ne $agent_name) {
    $pending = @($pending | Where-Object { [string]$_.AgentName -eq $agent_name })
}

$result_actions = [System.Collections.Generic.List[hashtable]]::new()
foreach ($action in $pending) {
    $result_actions.Add((Format-PendingManagementResult -action $action))
}

$module.Result.changed = $false
$module.Result.pending_management = $result_actions.ToArray()

$module.ExitJson()
