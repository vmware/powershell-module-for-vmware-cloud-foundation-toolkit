# VCF.Powershell.Toolbox

VMware Cloud Foundation PowerShell Workflow Automation Module

[![PowerShell](https://img.shields.io/badge/PowerShell-7.2%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![License](https://img.shields.io/badge/License-Broadcom-green.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.0.0.2-orange.svg)](CHANGELOG.md)

## Overview

**VCF.Powershell.Toolbox** is a comprehensive PowerShell module designed for VMware Cloud Foundation (VCF) automation and workflow management. This module provides essential connection management, logging, error handling, and utility functions for building robust VCF automation scripts and tools.

The module serves as a foundational toolbox for VCF administrators and developers, offering reusable functions that handle the complexity of connection management, authentication, logging, and user interaction, allowing you to focus on building your automation workflows.

## Features

### Connection Management
- **SDDC Manager Authentication**: Token-based authentication with automatic refresh and reconnection
- **vCenter Server Connections**: Unified connection management for vCenter and ESX hosts
- **Session Health Monitoring**: Automatic token expiration checking and connection validation
- **Credential Management**: Support for both JSON credential files and interactive authentication
- **Version Detection**: Automatic version detection and validation for SDDC Manager and vCenter

### Logging & Error Handling
- **Multi-Level Logging**: Color-coded console output with configurable log levels (DEBUG, INFO, ADVISORY, WARNING, EXCEPTION, ERROR)
- **File-Based Logging**: Automatic daily log file creation with timestamps
- **Structured Error Handling**: Standardized error result objects for consistent error management
- **Exit Code Management**: Standardized exit codes for automation and CI/CD integration

### Utility Functions
- **Safe JSON Parsing**: Robust JSON file loading with comprehensive error handling
- **Interactive User Input**: Standardized prompts for credentials and confirmations
- **Performance Timing**: High-precision operation timing and measurement
- **Environment Setup**: Automatic environment information gathering for troubleshooting
- **Array Validation**: Configuration data validation with detailed error reporting

## Requirements

### Software Requirements
- **PowerShell**: Version 7.2.0 or later
- **VCF.PowerCLI**: Version 9.0 or later

### Supported Platforms
- Windows
- macOS
- Linux

## Installation

### Option 1: Manual Installation

1. Clone or download this repository:
```powershell
git clone https://github.com/vmware/powershell-module-for-vmware-cloud-foundation-toolkit.git
```

2. Import the module:
```powershell
Import-Module ./VCF.Powershell.Toolbox.psd1
```

### Verify Installation

```powershell
Get-Module -Name VCF.Powershell.Toolbox -ListAvailable
```

## Quick Start

### Basic SDDC Manager Connection

```powershell
# Import the module
Import-Module VCF.Powershell.Toolbox

# Connect to SDDC Manager (interactive mode)
Connect-SddcManager

# Connect using a JSON credentials file
Connect-SddcManager -sddcManagerCredentialsJson "credentials.json"

# Perform your operations...

# Disconnect when finished
Disconnect-SddcManager -noPrompt
```

### vCenter Server Connection

```powershell
# Create credentials
$credential = Get-Credential -Message "Enter vCenter credentials"

# Connect to vCenter
Connect-Vcenter -serverName "vcenter.example.com" -serverCredential $credential -serverType "vCenter"

# Test connection health
$connectionTest = Test-VcenterConnection -serverName "vcenter.example.com"
if ($connectionTest.IsConnected) {
    Write-Host "Connection is healthy"
}

# Disconnect
Disconnect-Vcenter -allServers
```

### Logging Example

```powershell
# Initialize logging
New-LogFile -prefix "MyScript" -directory "logs"

# Log messages at different levels
Write-LogMessage -type INFO -message "Script started successfully"
Write-LogMessage -type WARNING -message "Configuration file not found, using defaults"
Write-LogMessage -type ERROR -message "Failed to connect to server"
Write-LogMessage -type DEBUG -message "Variable value: $myVariable"
```

### Timing Operations

```powershell
# Start timer
$timer = Start-ProcessTimer

# Perform your operation
Start-Sleep -Seconds 5

# Stop timer and log elapsed time
Stop-ProcessTimer -timer $timer -operation "Data processing" -interval "Seconds"
# Logs: "Data processing took 5.00 Seconds to complete."
```

## Credentials File Format

For automated/headless operations, you can create a JSON credentials file for SDDC Manager:

```json
{
    "sddcManagerFqdn": "sddc-manager.example.com",
    "sddcManagerUserName": "administrator@vsphere.local",
    "sddcManagerPassword": "YourSecurePassword"
}
```

**Security Note**: Store credential files securely with appropriate file system permissions. Consider using encrypted storage or secrets management solutions for production environments.

## Function Reference

### Connection Functions

| Function | Description |
|----------|-------------|
| `Connect-SddcManager` | Establishes authenticated connection to SDDC Manager |
| `Disconnect-SddcManager` | Safely disconnects from SDDC Manager |
| `Test-SddcManagerConnection` | Verifies connection health and handles reconnection |
| `Get-SddcManagerAccessTokenExpiry` | Calculates token TTL for proactive refresh |
| `Get-SddcManagerVersion` | Retrieves SDDC Manager version information |
| `Connect-Vcenter` | Connects to vCenter or ESX hosts |
| `Disconnect-Vcenter` | Disconnects from vCenter/ESX with verification |
| `Test-VcenterConnection` | Validates vCenter connection health |
| `Test-VCenterVersion` | Validates vCenter meets minimum version requirements |

### Utility Functions

| Function | Description |
|----------|-------------|
| `Write-LogMessage` | Multi-level logging with color-coded output |
| `New-LogFile` | Creates daily log file with automatic directory structure |
| `Start-ProcessTimer` | Initializes high-precision operation timer |
| `Stop-ProcessTimer` | Stops timer and logs elapsed time |
| `ConvertFrom-JsonSafely` | Safe JSON file parsing with error handling |
| `Get-InteractiveInput` | Prompts user for input with validation |
| `New-ChoiceMenu` | Interactive yes/no choice prompts |
| `Show-AnyKey` | Pauses execution for user acknowledgment |
| `Show-Version` | Displays module version information |
| `Get-EnvironmentSetup` | Gathers environment info for troubleshooting |
| `Test-EmptyValue` | Validates required string values |
| `Test-ArrayMissingProperties` | Validates configuration objects |
| `Test-LogLevel` | Determines if message should display based on log level |
| `Write-ErrorAndReturn` | Returns standardized error results |
| `Exit-WithCode` | Exits with standardized exit codes |

## Log Levels

The module supports six log levels with hierarchical filtering:

| Level | Description | Console Color |
|-------|-------------|---------------|
| DEBUG | Development and troubleshooting information | Gray |
| INFO | General informational messages | Green |
| ADVISORY | Guidance and recommendations | Yellow |
| WARNING | Warning conditions needing attention | Yellow |
| EXCEPTION | Exception details and stack traces | Cyan |
| ERROR | Error conditions requiring action | Red |

Configure the log level when calling your scripts to control console output verbosity. All messages are always written to log files regardless of level.

## Exit Codes

The module provides standardized exit codes for automation integration:

| Code | Category | Description |
|------|----------|-------------|
| 0 | SUCCESS | Operation completed successfully |
| 1 | GENERAL_ERROR | Unspecified error |
| 2 | PARAMETER_ERROR | Invalid parameters or validation failure |
| 3 | CONNECTION_ERROR | Failed to connect to SDDC Manager or vCenter |
| 4 | AUTHENTICATION_ERROR | Authentication or credential failure |
| 5 | RESOURCE_NOT_FOUND | Cluster, host, or domain not found |
| 6 | OPERATION_FAILED | Operation failed |
| 7 | TASK_FAILED | Background task failed or timed out |
| 8 | CONFIGURATION_ERROR | JSON or configuration file error |
| 9 | PRECONDITION_ERROR | Prerequisites not met |
| 10 | USER_CANCELLED | User cancelled the operation |

## Advanced Usage Examples

### Error Handling Pattern

```powershell
# Helper function returns structured error
function Get-ClusterInfo {
    param($clusterName)

    if (-not $cluster) {
        return Write-ErrorAndReturn `
            -errorMessage "Cluster '$clusterName' not found" `
            -errorCode "ERR_CLUSTER_NOT_FOUND"
    }
    return @{ Success = $true; Cluster = $cluster }
}

# Caller checks result and handles error
$result = Get-ClusterInfo -clusterName "Cluster-01"
if (-not $result.Success) {
    Write-LogMessage -type ERROR -message $result.ErrorMessage
    Exit-WithCode -exitCode $Script:ExitCodes.RESOURCE_NOT_FOUND -message "Cluster lookup failed"
}
```

### Automated Workflow with Token Management

```powershell
# Connect with automatic token refresh
Connect-SddcManager -sddcManagerCredentialsJson "prod-credentials.json"

# Perform long-running operations
foreach ($domain in $domains) {
    # Automatically check token and refresh if needed
    Test-SddcManagerConnection

    # Your operations here
    $result = Invoke-VcfGetDomain -id $domain.id
}

# Clean disconnect
Disconnect-SddcManager -noPrompt -silence
```

### JSON Configuration Validation

```powershell
# Load configuration
$config = ConvertFrom-JsonSafely -jsonFilePath "deployment.json"

# Validate required properties
$validation = Test-ArrayMissingProperties `
    -array $config.hosts `
    -requiredProperties @("hostname", "username", "password") `
    -arrayName "HostConfiguration"

if (-not $validation.IsValid) {
    Exit-WithCode -exitCode $Script:ExitCodes.CONFIGURATION_ERROR `
        -message "Configuration validation failed: $($validation.Summary)"
}
```

## Best Practices

1. **Always Use Logging**: Initialize logging with `New-LogFile` at the start of your scripts
2. **Connection Health**: Call `Test-SddcManagerConnection` before long-running operations
3. **Error Handling**: Use `Write-ErrorAndReturn` in helper functions and check `.Success` property
4. **Credentials Security**: Store credential files securely with restricted file permissions
5. **Exit Codes**: Use `Exit-WithCode` with standardized codes for automation integration
6. **Interactive vs Headless**: Design scripts to support both interactive and automated execution
7. **Version Validation**: Verify target system versions before attempting operations

## Troubleshooting

### Common Issues

**PowerCLI Not Found**
```
ERROR: Could not find PowerCLI cmdlet Connect-VcfSddcManagerServer
```
**Solution**: Install VMware PowerCLI: `Install-Module -Name VMware.PowerCLI -Scope CurrentUser`

**SSL Certificate Issues**
```
ERROR: SSL Connection error to SDDC Manager
```
**Solution**: Configure PowerCLI to trust self-signed certificates:
```powershell
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
```

**Token Expiration**
```
ERROR: JWT expired
```
**Solution**: Call `Test-SddcManagerConnection` before operations to auto-refresh tokens

### Debug Logging

Enable DEBUG level logging for detailed troubleshooting:

```powershell
$Script:configuredLogLevel = "DEBUG"
```

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch
3. Follow PowerShell best practices and existing code style
4. Add comprehensive comment-based help to new functions
5. Test your changes thoroughly
6. Submit a pull request with detailed description

## License

Copyright (c) 2025 Broadcom. All Rights Reserved.

This software is provided under the Broadcom license agreement. See the license headers in individual files for complete terms.

## Support

For issues, questions, or contributions:
- **Issues**: Open an issue on GitHub
- **Documentation**: See function help: `Get-Help <Function-Name> -Full`
- **Examples**: See examples in this README and function documentation

## Authors

- **Broadcom** - Initial development and maintenance

## Acknowledgments

- VMware Cloud Foundation team for platform support
- PowerShell community for best practices and patterns
- Contributors and testers

---

**Version**: 1.0.0.2
**Last Updated**: November 20, 2025
**PowerShell Version**: 7.2.0+
**Tags**: VMware, CloudFoundation, VMwareCloudFoundation, Automation, PowerShell

