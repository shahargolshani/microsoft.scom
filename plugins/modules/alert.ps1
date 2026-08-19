#!powershell

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ..module_utils._SCOMPsSetupUtils


# Maps Ansible module parameter names -> Set-SCOMAlert cmdlet parameter names (direct string/int mapping)
$ALERT_DIRECT_PARAMS = @{
    owner = "Owner"
    ticket_id = "TicketId"
    custom_field1 = "CustomField1"
    custom_field2 = "CustomField2"
    custom_field3 = "CustomField3"
    custom_field4 = "CustomField4"
    custom_field5 = "CustomField5"
    custom_field6 = "CustomField6"
    custom_field7 = "CustomField7"
    custom_field8 = "CustomField8"
    custom_field9 = "CustomField9"
    custom_field10 = "CustomField10"
}

# Resolution state name -> integer mapping (0 and 255 are SCOM-reserved)
$RESOLUTION_STATE_MAP = @{
    new = 0
    closed = 255
}


Function Format-AlertResult {
    param (
        [Parameter(Mandatory = $true)][object]$alert
    )

    return @{
        id = $alert.Id.ToString()
        name = $alert.Name
        description = if ($null -ne $alert.Description) { $alert.Description } else { "" }
        severity = ConvertTo-SCOMSeverityString -SeverityValue ([int]$alert.Severity)
        resolution_state = [int]$alert.ResolutionState
        resolution_state_name = ConvertTo-SCOMResolutionStateString -ResolutionState ([int]$alert.ResolutionState)
        owner = if ($null -ne $alert.Owner) { $alert.Owner } else { "" }
        ticket_id = if ($null -ne $alert.TicketId) { $alert.TicketId } else { "" }
        monitoring_object_name = if ($null -ne $alert.MonitoringObjectDisplayName) { $alert.MonitoringObjectDisplayName } else { "" }
        time_raised = Format-DateTimeAsStringSafely -dateTimeObject $alert.TimeRaised
        last_modified = Format-DateTimeAsStringSafely -dateTimeObject $alert.LastModified
        resolved_by = if ($null -ne $alert.ResolvedBy) { $alert.ResolvedBy } else { "" }
        time_resolved = Format-DateTimeAsStringSafely -dateTimeObject $alert.TimeResolved
    }
}


Function Test-AlertNeedsUpdate {
    <#
    Compares the desired module parameters against the current alert state.
    Returns $true when at least one property differs and an update is required.
    #>
    param (
        [Parameter(Mandatory = $true)][object]$module,
        [Parameter(Mandatory = $true)][object]$alert,
        [Parameter(Mandatory = $false)][AllowNull()][int]$desired_resolution_state = $null
    )

    if ($null -ne $module.Params.owner -and $alert.Owner -ne $module.Params.owner) {
        return $true
    }
    if ($null -ne $module.Params.ticket_id -and $alert.TicketId -ne $module.Params.ticket_id) {
        return $true
    }
    if ($null -ne $desired_resolution_state -and ([int]$alert.ResolutionState) -ne $desired_resolution_state) {
        return $true
    }

    foreach ($param in $ALERT_DIRECT_PARAMS.Keys) {
        if ($null -ne $module.Params.$param -and $alert.$($ALERT_DIRECT_PARAMS.$param) -ne $module.Params.$param) {
            return $true
        }
    }

    return $false
}


$spec = @{
    options = @{
        alert_id = @{ type = "str"; required = $true }
        resolution_state = @{
            type = "str"
            required = $false
            default = $null
            choices = @("new", "closed")
        }
        owner = @{ type = "str"; required = $false; default = $null }
        ticket_id = @{ type = "str"; required = $false; default = $null }
        custom_field1 = @{ type = "str"; required = $false; default = $null }
        custom_field2 = @{ type = "str"; required = $false; default = $null }
        custom_field3 = @{ type = "str"; required = $false; default = $null }
        custom_field4 = @{ type = "str"; required = $false; default = $null }
        custom_field5 = @{ type = "str"; required = $false; default = $null }
        custom_field6 = @{ type = "str"; required = $false; default = $null }
        custom_field7 = @{ type = "str"; required = $false; default = $null }
        custom_field8 = @{ type = "str"; required = $false; default = $null }
        custom_field9 = @{ type = "str"; required = $false; default = $null }
        custom_field10 = @{ type = "str"; required = $false; default = $null }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$alert_id = $module.Params.alert_id
$resolution_state = $module.Params.resolution_state

Import-SCOMPsModule -module $module
Connect-SCOMManagementGroup -Module $module

$alert = $null
try {
    $alert = Get-SCOMAlert -Id $alert_id -ErrorAction Stop
}
catch {
    $module.FailJson("Failed to retrieve SCOM alert with ID '$alert_id': $($_.Exception.Message)", $_)
}

if ($null -eq $alert) {
    $module.FailJson("No SCOM alert found with ID '$alert_id'.")
}

$desired_resolution_state_int = $null
if ($null -ne $resolution_state) {
    $desired_resolution_state_int = $RESOLUTION_STATE_MAP[$resolution_state]
}

$needs_update = Test-AlertNeedsUpdate `
    -module $module `
    -alert $alert `
    -desired_resolution_state $desired_resolution_state_int

if (-not $needs_update) {
    $module.Result.changed = $false
    $module.Result.alert = Format-AlertResult -alert $alert
    $module.ExitJson()
}

$module.Result.changed = $true

if (-not $module.CheckMode) {
    $set_arguments = Format-ModuleParamAsCmdletArgument `
        -module $module `
        -direct_mapped_params $ALERT_DIRECT_PARAMS `
        -datetime_params @{} `
        -switch_params @{}

    if ($set_arguments.Count -gt 0) {
        try {
            $alert | Set-SCOMAlert @set_arguments -ErrorAction Stop
        }
        catch {
            $module.FailJson("Failed to update SCOM alert '$alert_id': $($_.Exception.Message)", $_)
        }
    }

    if ($null -ne $desired_resolution_state_int) {
        try {
            if ($desired_resolution_state_int -eq 255) {
                $alert | Resolve-SCOMAlert -ErrorAction Stop
            }
            else {
                $alert | Set-SCOMAlert -ResolutionState $desired_resolution_state_int -ErrorAction Stop
            }
        }
        catch {
            $module.FailJson(
                "Failed to set resolution state '$resolution_state' on alert '$alert_id': $($_.Exception.Message)", $_
            )
        }
    }

    try {
        $alert = Get-SCOMAlert -Id $alert_id -ErrorAction Stop
    }
    catch {
        $module.Warn("Alert was updated but could not be re-fetched for result: $($_.Exception.Message)")
    }
}

$module.Result.alert = Format-AlertResult -alert $alert

$module.ExitJson()
