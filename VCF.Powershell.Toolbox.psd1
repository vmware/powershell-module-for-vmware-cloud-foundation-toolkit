# Copyright (c) 2025 Broadcom. All Rights Reserved.
# Broadcom Confidential. The term "Broadcom" refers to Broadcom Inc.
# and/or its subsidiaries.
#
# =============================================================================
#
# SOFTWARE LICENSE AGREEMENT
#
#
# Copyright (c) CA, Inc. All rights reserved.
#
#
# You are hereby granted a non-exclusive, worldwide, royalty-free license
# under CA, Inc.'s copyrights to use, copy, modify, and distribute this
# software in source code or binary form for use in connection with CA, Inc.
# products.
#
#
# This copyright notice shall be included in all copies or substantial
# portions of the software.
#
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.
#
# =============================================================================
#
# Generated on: 2025-11-20
#
@{

    # Script module or binary module file associated with this manifest.
    #RootModule = ''

    # Version number of this module.
    ModuleVersion = '1.0.0.2'

    # Supported PSEditions
    # CompatiblePSEditions = @()

    # ID used to uniquely identify this module
    GUID = 'e9cc185d-004b-45f8-83bd-ef361c334254'

    # Author of this module
    Author = 'Broadcom'

    # Company or vendor of this module
    CompanyName = 'Broadcom, Inc.'

    # Copyright statement for this module
    Copyright = 'Copyright (c) Broadcom. All Rights Reserved.'

    # Description of the functionality provided by this module
    Description = 'VMware Cloud Foundation Powershell Workflow Automation Module.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.2.0'

    # Name of the PowerShell host required by this module
    # PowerShellHostName = ''

    # Minimum version of the PowerShell host required by this module
    # PowerShellHostVersion = ''

    # Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # DotNetFrameworkVersion = ''

    # Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # ClrVersion = ''

    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = ''

    # Modules that must be imported into the global environment prior to importing this module
    # RequiredModules = @()

    # Assemblies that must be loaded prior to importing this module
    # RequiredAssemblies = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    # ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    # FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules = @('Connection.Functions.psm1','Utility.Functions.psm1')

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        # Utility.Functions :
        'ConvertFrom-JsonSafely',             # Safe JSON file parsing with error handling
        'Exit-WithCode',                      # Standardized script exit with exit codes
        'Get-EnvironmentSetup',               # Environment information gathering for troubleshooting
        'Get-InteractiveInput',               # Interactive credential collection
        'New-ChoiceMenu',                     # Interactive yes/no user prompts
        'New-LogFile',                        # Log file creation and management
        'Show-AnyKey',                        # "Press any key to continue" functionality
        'Show-Version',                       # Display module version information
        'Start-ProcessTimer',                 # Operation timing
        'Stop-ProcessTimer',                  # Timer completion and logging
        'Test-ArrayMissingProperties',        # Look for missing properties in arrays
        'Test-EmptyValue',                    # Empty value validation
        'Test-LogLevel',                      # Log level threshold testing
        'Write-ErrorAndReturn',               # Standardized error result generation
        'Write-LogMessage',                   # Core logging functionality with color-coded output
        # Connection.Functions - SDDC Manager
        'Connect-SddcManager',                # SDDC Manager authentication and connection
        'Disconnect-SddcManager',             # SDDC Manager disconnection
        'Get-SddcManagerAccessTokenExpiry',   # Token expiration monitoring
        'Get-SddcManagerVersion',             # SDDC Manager version information
        'Test-SddcManagerConnection',         # Connection health validation and auto-reconnect
        # Connection.Functions - vCenter Server
        'Connect-Vcenter',                    # vCenter/ESX host authentication and connection
        'Disconnect-Vcenter',                 # vCenter/ESX host disconnection
        'Test-VcenterConnection',             # vCenter connection validation
        'Test-VCenterVersion'                 # vCenter version validation
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = '*'

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()

    # DSC resources to export from this module
    # DscResourcesToExport = @()

    # List of all modules packaged with this module
    # ModuleList = @()

    # List of all files packaged with this module
    # FileList = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{

        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags         = @('VMware', 'CloudFoundation', 'VMwareCloudFoundation')

            # A URL to the license for this module.
            # LicenseUri = ''

            # A URL to the main website for this project.
            # ProjectUri = ''

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            # ReleaseNotes = ''

            # Prerelease string of this module
            # Prerelease = ''

            # Flag to indicate whether the module requires explicit user acceptance for install/update/save
            # RequireLicenseAcceptance = $false

            # External dependent modules of this module
            # ExternalModuleDependencies = @()

        } # End of PSData hashtable

    } # End of PrivateData hashtable

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''

    }