#!powershell

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ..module_utils._SCOMPsSetupUtils


Function Format-ManagementPackResult {
    param (
        [Parameter(Mandatory = $true)][object]$mp
    )

    return @{
        id = $mp.Id.ToString()
        name = $mp.Name
        display_name = if ($null -ne $mp.DisplayName) { $mp.DisplayName } else { "" }
        version = if ($null -ne $mp.Version) { $mp.Version.ToString() } else { "" }
        sealed = [bool]$mp.Sealed
        time_created = Format-DateTimeAsStringSafely -dateTimeObject $mp.TimeCreated
        last_modified = Format-DateTimeAsStringSafely -dateTimeObject $mp.LastModified
    }
}


Function Get-ManagementPackFromFile {
    <#
    Loads the management pack definition(s) from a file on the SCOM host without
    importing them, so the identity and version can be compared against the
    installed state. Returns $null when the file cannot be read as an MP.
    #>
    param (
        [Parameter(Mandatory = $true)][string]$path
    )

    $extension = [System.IO.Path]::GetExtension($path).ToLowerInvariant()
    try {
        if ($extension -eq ".mpb") {
            return @(Get-SCOMManagementPack -BundleFile $path -ErrorAction Stop)
        }
        return @(Get-SCOMManagementPack -ManagementPackFile $path -ErrorAction Stop)
    }
    catch {
        return $null
    }
}


$spec = @{
    options = @{
        path = @{ type = "str"; required = $false; default = $null }
        name = @{ type = "str"; required = $false; default = $null }
        state = @{
            type = "str"
            required = $false
            default = "present"
            choices = @("present", "absent")
        }
    }
    required_if = @(
        @("state", "present", @("path")),
        @("state", "absent", @("name"))
    )
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$path = $module.Params.path
$name = $module.Params.name
$state = $module.Params.state

Import-SCOMPsModule -module $module
Connect-SCOMManagementGroup -Module $module

if ($state -eq "absent") {
    $installed = $null
    try {
        $installed = Get-SCOMManagementPack -Name $name -ErrorAction SilentlyContinue
    }
    catch {
        $module.FailJson("Failed to query SCOM management pack '$name': $($_.Exception.Message)", $_)
    }

    if ($null -eq $installed) {
        $module.Result.changed = $false
        $module.ExitJson()
    }

    $module.Result.changed = $true
    if (-not $module.CheckMode) {
        try {
            $installed | Remove-SCOMManagementPack -ErrorAction Stop
        }
        catch {
            $module.FailJson(
                "Failed to remove SCOM management pack '$name'. It may be sealed and required by other " +
                "management packs: $($_.Exception.Message)", $_
            )
        }
    }
    $module.ExitJson()
}

# state == present
if (-not (Test-Path -LiteralPath $path)) {
    $module.FailJson("Management pack file '$path' does not exist on the SCOM host.")
}

$file_mps = Get-ManagementPackFromFile -path $path

$needs_update = $false
if ($null -eq $file_mps) {
    # Could not read the identity from the file (e.g. a sealed pack the SDK will not
    # pre-load). Fall back to attempting the import and treating an "already imported"
    # failure as no change.
    $needs_update = $true
    $unknown_identity = $true
}
else {
    $unknown_identity = $false
    foreach ($file_mp in $file_mps) {
        $installed = Get-SCOMManagementPack -Name $file_mp.Name -ErrorAction SilentlyContinue
        if ($null -eq $installed) {
            $needs_update = $true
        }
        elseif ([version]$installed.Version -lt [version]$file_mp.Version) {
            $needs_update = $true
        }
    }
}

if (-not $needs_update) {
    $module.Result.changed = $false
    $primary = Get-SCOMManagementPack -Name $file_mps[0].Name -ErrorAction SilentlyContinue
    if ($null -ne $primary) {
        $module.Result.management_pack = Format-ManagementPackResult -mp $primary
    }
    $module.ExitJson()
}

$module.Result.changed = $true

if (-not $module.CheckMode) {
    try {
        Import-SCOMManagementPack -FullName $path -ErrorAction Stop
    }
    catch {
        if ($unknown_identity -and $_.Exception.Message -match "already") {
            # The pack (or a newer version) is already imported and its identity could
            # not be pre-read from the file; treat as no change.
            $module.Result.changed = $false
            $module.ExitJson()
        }
        $module.FailJson("Failed to import SCOM management pack from '$path': $($_.Exception.Message)", $_)
    }

    if (-not $unknown_identity) {
        $primary = Get-SCOMManagementPack -Name $file_mps[0].Name -ErrorAction SilentlyContinue
        if ($null -ne $primary) {
            $module.Result.management_pack = Format-ManagementPackResult -mp $primary
        }
    }
}

$module.ExitJson()
