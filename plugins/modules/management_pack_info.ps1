#!powershell

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ..module_utils._SCOMPsSetupUtils



$spec = @{
    options = @{
        name = @{ type = "str"; required = $false; default = $null }
        display_name = @{ type = "str"; required = $false; default = $null }
        id = @{ type = "str"; required = $false; default = $null }
    }
    mutually_exclusive = @(
        @("name", "id"),
        @("display_name", "id")
    )
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$name = $module.Params.name
$display_name = $module.Params.display_name
$id = $module.Params.id

Import-SCOMPsModule -module $module
Connect-SCOMManagementGroup -Module $module

$management_packs = $null
try {
    if ($null -ne $id) {
        $management_packs = Get-SCOMManagementPack -Id $id -ErrorAction Stop
    }
    elseif ($null -ne $name) {
        $management_packs = Get-SCOMManagementPack -Name $name -ErrorAction Stop
    }
    elseif ($null -ne $display_name) {
        $management_packs = Get-SCOMManagementPack -DisplayName $display_name -ErrorAction Stop
    }
    else {
        $management_packs = Get-SCOMManagementPack -ErrorAction Stop
    }
}
catch {
    $module.FailJson("Failed to retrieve SCOM management packs: $($_.Exception.Message)", $_)
}

$result_mps = [System.Collections.Generic.List[hashtable]]::new()
if ($null -ne $management_packs) {
    foreach ($mp in $management_packs) {
        $result_mps.Add((Format-ManagementPackResult -mp $mp))
    }
}

$module.Result.changed = $false
$module.Result.management_packs = $result_mps.ToArray()

$module.ExitJson()
