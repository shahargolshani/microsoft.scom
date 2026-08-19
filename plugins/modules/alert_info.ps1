#!powershell

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ..module_utils._SCOMPsSetupUtils


Function Format-AlertResult {
    param (
        [Parameter(Mandatory = $true)][object]$alert
    )

    return @{
        id = $alert.Id.ToString()
        name = $alert.Name
        description = if ($null -ne $alert.Description) { $alert.Description } else { "" }
        severity = ConvertTo-SCOMSeverityString -SeverityValue ([int]$alert.Severity)
        priority = [int]$alert.Priority
        resolution_state = [int]$alert.ResolutionState
        resolution_state_name = ConvertTo-SCOMResolutionStateString -ResolutionState ([int]$alert.ResolutionState)
        monitoring_object_id = if ($null -ne $alert.MonitoringObjectId) { $alert.MonitoringObjectId.ToString() } else { "" }
        monitoring_object_name = if ($null -ne $alert.MonitoringObjectDisplayName) { $alert.MonitoringObjectDisplayName } else { "" }
        monitoring_object_path = if ($null -ne $alert.MonitoringObjectPath) { $alert.MonitoringObjectPath } else { "" }
        monitor_id = if ($null -ne $alert.MonitoringRuleId) { $alert.MonitoringRuleId.ToString() } else { "" }
        owner = if ($null -ne $alert.Owner) { $alert.Owner } else { "" }
        ticket_id = if ($null -ne $alert.TicketId) { $alert.TicketId } else { "" }
        time_raised = Format-DateTimeAsStringSafely -dateTimeObject $alert.TimeRaised
        time_added = Format-DateTimeAsStringSafely -dateTimeObject $alert.TimeAdded
        last_modified = Format-DateTimeAsStringSafely -dateTimeObject $alert.LastModified
        resolved_by = if ($null -ne $alert.ResolvedBy) { $alert.ResolvedBy } else { "" }
        time_resolved = Format-DateTimeAsStringSafely -dateTimeObject $alert.TimeResolved
        custom_field1 = if ($null -ne $alert.CustomField1) { $alert.CustomField1 } else { "" }
        custom_field2 = if ($null -ne $alert.CustomField2) { $alert.CustomField2 } else { "" }
    }
}


$spec = @{
    options = @{
        criteria = @{ type = "str"; required = $false; default = $null }
        severity = @{
            type = "str"
            required = $false
            default = $null
            choices = @("information", "warning", "critical")
        }
        resolution_state = @{
            type = "str"
            required = $false
            default = $null
            choices = @("new", "closed", "any")
        }
        monitoring_object = @{ type = "str"; required = $false; default = $null }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$criteria = $module.Params.criteria
$severity = $module.Params.severity
$resolution_state = $module.Params.resolution_state
$monitoring_object = $module.Params.monitoring_object

Import-SCOMPsModule -module $module
Connect-SCOMManagementGroup -Module $module

$alert_criteria_parts = [System.Collections.Generic.List[string]]::new()

if ($null -ne $criteria -and $criteria -ne "") {
    $alert_criteria_parts.Add("($criteria)")
}

if ($null -ne $severity) {
    $severity_map = @{
        information = 0
        warning = 1
        critical = 2
    }
    $alert_criteria_parts.Add("(Severity = '$($severity_map[$severity])')")
}

if ($null -ne $resolution_state -and $resolution_state -ne "any") {
    $state_map = @{
        new = 0
        closed = 255
    }
    $alert_criteria_parts.Add("(ResolutionState = '$($state_map[$resolution_state])')")
}

if ($null -ne $monitoring_object -and $monitoring_object -ne "") {
    $alert_criteria_parts.Add("(MonitoringObjectDisplayName LIKE '%$monitoring_object%')")
}

$alerts = $null
try {
    if ($alert_criteria_parts.Count -gt 0) {
        $combined_criteria = $alert_criteria_parts -join " AND "
        $alerts = Get-SCOMAlert -Criteria $combined_criteria -ErrorAction Stop
    }
    else {
        $alerts = Get-SCOMAlert -ErrorAction Stop
    }
}
catch {
    $module.FailJson("Failed to retrieve SCOM alerts: $($_.Exception.Message)", $_)
}

$result_alerts = [System.Collections.Generic.List[hashtable]]::new()
if ($null -ne $alerts) {
    foreach ($alert in $alerts) {
        $result_alerts.Add((Format-AlertResult -alert $alert))
    }
}

$module.Result.changed = $false
$module.Result.alerts = $result_alerts.ToArray()

$module.ExitJson()
