# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

from __future__ import absolute_import, division, print_function

__metaclass__ = type


class ModuleDocFragment:
    """Common documentation for modules that use the OperationsManager PowerShell module."""

    DOCUMENTATION = r"""
notes:
    - These modules must run directly on the SCOM Management Server via WinRM. The
      OperationsManager PowerShell module is only installed on hosts where the SCOM
      Operations Console has been installed, and the SDK auto-connects to the local
      Management Group on import. Running on any other Windows host will fail.
    - "Supported SCOM versions: 2012 R2, 2016, 2019, 2022."
    - The account executing this module must hold at minimum the SCOM Operators role
      on the Management Group. Administrative operations (e.g. importing management
      packs) require the SCOM Administrators role.

requirements:
    - Must execute on the SCOM Management Server via WinRM
    - SCOM Operations Console installed on the target host (provides the OperationsManager
      PowerShell module or the legacy Microsoft.EnterpriseManagement PSSnapins)
    - SCOM 2012 R2, 2016, 2019, or 2022
    - SCOM Operators role (minimum) for the executing account

options: {}
"""
