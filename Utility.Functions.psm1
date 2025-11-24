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
#
# VCF.PS.Toolbox - Utility Functions Module
#
# This module provides essential utility functions for the VCF PowerShell Toolbox,
# including logging, environment setup, timing operations, JSON processing, and
# user interface helpers. These functions are designed to be reusable across
# multiple VCF automation scripts and provide consistent error handling and
# logging capabilities.
#
# Key Features:
# - Multi-level logging with color-coded console output and file logging
# - Log level filtering (DEBUG, INFO, ADVISORY, WARNING, EXCEPTION, ERROR)
# - Standardized error handling with structured error result objects
# - Environment information gathering for troubleshooting
# - High-precision operation timing and performance measurement
# - Safe JSON file parsing with comprehensive error handling
# - Interactive user input collection with validation
# - Configurable yes/no choice menus for user confirmation
# - Array validation for missing properties in configuration objects
#
# Last modified: 2025-11-19
#
Function Test-LogLevel {

    <#
        .SYNOPSIS
        Determines if a message should be displayed based on the configured log level.

        .DESCRIPTION
        Compares the message type against the configured log level threshold to determine
        if the message should be displayed on screen. All messages are always written to
        the log file regardless of level.

        The log level hierarchy from lowest to highest is:
        DEBUG < INFO < ADVISORY < WARNING < EXCEPTION < ERROR

        .PARAMETER messageType
        The type/severity of the log message to check.

        .PARAMETER configuredLevel
        The minimum log level configured for screen output.

        .EXAMPLE
        Test-LogLevel -messageType "DEBUG" -configuredLevel "INFO"
        Returns $false because DEBUG is below INFO threshold.

        .EXAMPLE
        Test-LogLevel -messageType "ERROR" -configuredLevel "INFO"
        Returns $true because ERROR is at or above INFO threshold.

        .OUTPUTS
        Boolean
        Returns $true if the message should be displayed, $false otherwise.

    #>
    Param(
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [String]$configuredLevel,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [String]$messageType
    )

    $messageLevel = $Script:logLevelHierarchy[$messageType]
    $configuredLevelValue = $Script:logLevelHierarchy[$configuredLevel]

    return ($messageLevel -ge $configuredLevelValue)
}
Function Write-ErrorAndReturn {

    <#
        .SYNOPSIS
        Writes an error message and returns a standardized error result.

        .DESCRIPTION
        This function provides a standardized way to handle errors by logging the error
        message and returning a consistent error result object. This replaces the need
        for throw statements and provides better error handling consistency.

        USAGE GUIDELINES:
        - Use in Helper/Validation/Utility functions (not main workflow functions)
        - Allows caller to decide how to handle the error (propagate, retry, or exit)
        - Always check the returned Success property in the caller

        Error Handling Pattern:
        1. Helper function calls Write-ErrorAndReturn to return structured error
        2. Caller checks $result.Success
        3. Caller decides: propagate error, retry operation, or exit script

        .PARAMETER errorMessage
        The error message to log and include in the result.

        .PARAMETER errorCode
        Optional error code for categorization. Defaults to "ERR_UNKNOWN".

        Error Code Categories:
        - Connection Errors (1xxx):
          ERR_NOT_CONNECTED_SDDC, ERR_NOT_CONNECTED_VCENTER, ERR_CONNECTION_TIMEOUT,
          ERR_CONNECTION_FAILED, ERR_AUTH_FAILED, ERR_TOKEN_EXPIRED

        - Validation Errors (2xxx):
          ERR_INVALID_PARAMETER, ERR_INVALID_JSON, ERR_MISSING_PARAMETER,
          ERR_FILE_NOT_FOUND, ERR_INVALID_CREDENTIALS, ERR_VALIDATION_FAILED

        - Resource Errors (3xxx):
          ERR_CLUSTER_NOT_FOUND, ERR_IMAGE_NOT_FOUND, ERR_DOMAIN_NOT_FOUND,
          ERR_RESOURCE_NOT_FOUND, ERR_VCENTER_NOT_FOUND, ERR_HOST_NOT_FOUND

        - Operation Errors (4xxx):
          ERR_COMPLIANCE_CHECK_FAILED, ERR_TRANSITION_FAILED, ERR_IMPORT_FAILED,
          ERR_DELETE_FAILED, ERR_TASK_FAILED, ERR_OPERATION_FAILED

        - Task Errors (5xxx):
          ERR_TASK_IN_PROGRESS, ERR_TASK_CANCELLED, ERR_TASK_TIMEOUT,
          ERR_TASK_UNKNOWN_STATE, ERR_RETRY_FAILED

        - JSON/Configuration Errors (6xxx):
          ERR_JSON_PARSE, ERR_JSON_FORMAT, ERR_CONFIG_INVALID,
          ERR_REMEDIATION_OPTIONS_INVALID

        .EXAMPLE
        # Helper function returns error object
        Function Get-ClusterInfo {
            if (-not $cluster) {
                return Write-ErrorAndReturn `
                    -errorMessage "Cluster '$clusterName' not found in workload domain '$workloadDomainName'" `
                    -errorCode "ERR_CLUSTER_NOT_FOUND"
            }
            return @{ Success = $true; Cluster = $cluster }
        }

        .EXAMPLE
        # Caller checks result and decides how to handle
        $result = Get-ClusterInfo -clusterName $clusterName -workloadDomainName $workloadDomainName
        if (-not $result.Success) {
            Write-LogMessage -type ERROR -message "Failed to get cluster info: $($result.ErrorMessage)"
            exit 1  # Main workflow decides to exit
        }
        $cluster = $result.Cluster

        .OUTPUTS
        PSCustomObject
        Returns a hashtable with Success=$false, ErrorMessage, and ErrorCode properties.

        .NOTES
        Error Handling: This is a utility function used by helper/validation functions to return
        standardized error objects. Do NOT use 'exit 1' in helper functions; use this
        function instead to allow the caller to control error handling.

    #>
    Param(
        [Parameter(Mandatory = $false)] [ValidateNotNullOrEmpty()] [String]$errorCode = "ERR_UNKNOWN",
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [String]$errorMessage
    )

    Write-LogMessage -type ERROR -message $errorMessage

    return @{
        Success = $false
        ErrorMessage = $errorMessage
        ErrorCode = $errorCode
    }
}
Function Exit-WithCode {

    <#
        .SYNOPSIS
        Exits the script with a standardized exit code and optional final message.

        .DESCRIPTION
        This function provides a centralized exit point that ensures consistent exit code usage,
        optional cleanup operations, and clear logging before script termination. Using this
        function instead of direct 'exit' calls improves automation integration and debugging.

        Benefits of standardized exit codes:
        - CI/CD pipelines can distinguish between failure types and implement appropriate retry logic
        - Monitoring systems can categorize failures for better alerting and reporting
        - Debugging is faster with clear failure category indication
        - Follows PowerShell and Unix conventions for exit codes

        Exit Code Categories (see $Script:ExitCodes):
        0  - SUCCESS: Operation completed successfully
        1  - GENERAL_ERROR: Unspecified error
        2  - PARAMETER_ERROR: Invalid parameters or validation failure
        3  - CONNECTION_ERROR: Failed to connect to SDDC Manager or vCenter
        4  - AUTHENTICATION_ERROR: Authentication or credential failure
        5  - RESOURCE_NOT_FOUND: Cluster, host, workload domain, or image not found
        6  - OPERATION_FAILED: Operation (transition, import, compliance) failed
        7  - TASK_FAILED: Background task failed or timed out
        8  - CONFIGURATION_ERROR: JSON or configuration file error
        9  - PRECONDITION_ERROR: Prerequisites not met (modules, versions)
        10 - USER_CANCELLED: User cancelled the operation

        .PARAMETER exitCode
        The exit code to return to the shell. Use values from $Script:ExitCodes hashtable
        for consistency and self-documentation.

        .PARAMETER message
        Optional final message to log before exiting. If exitCode is 0, logs as INFO.
        Otherwise logs as ERROR.

        .PARAMETER noCleanup
        Skip optional cleanup operations before exit. Use this when cleanup has already
        been performed or is not desired.

        .EXAMPLE
        Exit-WithCode -exitCode $Script:ExitCodes.PARAMETER_ERROR -message "Invalid cluster name format"

        Exits with code 2 and logs an error message about invalid parameters.

        .EXAMPLE
        Exit-WithCode -exitCode $Script:ExitCodes.SUCCESS -message "Transition completed successfully"

        Exits with code 0 and logs a success message.

        .EXAMPLE
        Exit-WithCode -exitCode $Script:ExitCodes.CONNECTION_ERROR -message "Failed to connect to SDDC Manager" -noCleanup

        Exits with code 3, logs error, and skips cleanup operations.

        .OUTPUTS
        None. This function terminates the script with the specified exit code.

        .NOTES
        This function should be used for all script exits except in the main menu's exit option,
        which may have its own cleanup logic. Using this consistently throughout the script
        ensures predictable exit behavior for automation and debugging.
    #>
    Param(
        [Parameter(Mandatory = $true)] [ValidateNotNull()] [Int]$exitCode,
        [Parameter(Mandatory = $false)] [AllowEmptyString()] [String]$message,
        [Parameter(Mandatory = $false)] [Switch]$noCleanup
    )

    Write-LogMessage -type DEBUG -message "Entered Exit-WithCode function..."

    # Log final message if provided.
    if ($message) {
        if ($exitCode -eq 0) {
            Write-LogMessage -type INFO -message $message
        } else {
            Write-LogMessage -type ERROR -message $message
        }
    }

    # Optional cleanup logic for error exits.
    if (-not $noCleanup -and $exitCode -ne 0) {
        Write-LogMessage -type DEBUG -message "Exit code $exitCode indicates failure."
    }

    # Log the exit code for debugging.
    Write-LogMessage -type DEBUG -message "Script exiting with code $exitCode"

    # Exit with the specified code.
    exit $exitCode
}
Function Write-LogMessage {

    <#
        .SYNOPSIS
        Writes a severity-based color-coded message to the console and/or log file.

        .DESCRIPTION
        The Write-LogMessage function provides centralized logging functionality with support for
        different message types (INFO, ERROR, WARNING, EXCEPTION, ADVISORY, DEBUG). Messages are displayed
        on the console with color coding based on severity and written to a log file with timestamps.
        This function supports flexible output control allowing messages to be suppressed from either
        the console or log file as needed.

        Screen output is filtered based on the configured log level threshold (set via the -LogLevel
        script parameter). Only messages at or above the configured level are displayed on screen.
        All messages are always written to the log file regardless of their severity level.

        Log level hierarchy (lowest to highest):
        DEBUG < INFO < ADVISORY < WARNING < EXCEPTION < ERROR

        .PARAMETER message
        The message content to be logged and/or displayed. Can be an empty string if needed.

        .PARAMETER type
        The severity level of the message. Valid values are:
        - DEBUG (Gray): Debug information for troubleshooting and development
        - INFO (Green): General information messages
        - ADVISORY (Yellow): Advisory information for user guidance
        - WARNING (Yellow): Warning conditions that may need attention
        - EXCEPTION (Cyan): Exception details and stack traces
        - ERROR (Red): Error conditions that require attention
        Default value is "INFO".

        .PARAMETER suppressOutputToScreen
        When specified, prevents the message from being displayed on the console regardless of log level.

        .PARAMETER suppressOutputToFile
        When specified, prevents the message from being written to the log file.

        .PARAMETER prependNewLine
        When specified, adds a blank line before displaying the message on the console.
        This parameter has no effect when SuppressOutputToScreen is used or when the message
        is filtered by log level threshold.

        .PARAMETER appendNewLine
        When specified, adds a blank line after displaying the message on the console.
        This parameter has no effect when SuppressOutputToScreen is used or when the message
        is filtered by log level threshold.

        .EXAMPLE
        Write-LogMessage -type INFO -message "Process started successfully"
        Displays an informational message in green on the console and writes the message to the log file.

        .EXAMPLE
        Write-LogMessage -type ERROR -message "Failed to connect to server" -prependNewLine
        Displays an error message in red with a blank line before it, and logs it to the file.

        .EXAMPLE
        Write-LogMessage -type WARNING -message "Configuration file not found, using defaults" -suppressOutputToScreen
        Writes a warning message to the log file only, without displaying it on the console.

        .EXAMPLE
        Write-LogMessage -type ADVISORY -message "Consider updating your configuration" -suppressOutputToFile
        Displays an advisory message on the console only, without writing it to the log file.

        .EXAMPLE
        Write-LogMessage -type DEBUG -message "Variable value: $myVar = $($myVar)"
        Displays a debug message in gray on the console (only if log level is DEBUG) and writes it to the log file.

        .NOTES
        The function relies on the $Script:LogFile, $Script:logOnly, and $Script:configuredLogLevel variables being set.
        The log file path should be established using the New-LogFile function before calling this function.
        The $Script:configuredLogLevel should be set during script initialization.

        .OUTPUTS
        None
        This function does not return a value. It writes messages to console and/or log file.
    #>

    Param(
        [Parameter(Mandatory = $false)] [ValidateNotNullOrEmpty()] [Switch]$appendNewLine,
        [Parameter(Mandatory = $true)] [AllowEmptyString()] [String]$message,
        [Parameter(Mandatory = $false)] [ValidateNotNullOrEmpty()] [Switch]$prependNewLine,
        [Parameter(Mandatory = $false)] [ValidateNotNullOrEmpty()] [Switch]$suppressOutputToFile,
        [Parameter(Mandatory = $false)] [ValidateNotNullOrEmpty()] [Switch]$suppressOutputToScreen,
        [Parameter(Mandatory = $false)] [ValidateSet("INFO", "ERROR", "WARNING", "EXCEPTION", "ADVISORY", "DEBUG")] [String]$type = "INFO"
    )

    # Define color mapping for different message types.
    $msgTypeToColor = @{
        "INFO" = "Green";
        "ERROR" = "Red" ;
        "WARNING" = "Yellow" ;
        "ADVISORY" = "Yellow" ;
        "EXCEPTION" = "Cyan";
        "DEBUG" = "Gray"
    }

    # Get the appropriate color for the message type.
    $messageColor = $msgTypeToColor.$type

    # Create timestamp for log file entries (MM-dd-yyyy_HH:mm:ss format)
    $timeStamp = Get-Date -Format "MM-dd-yyyy_HH:mm:ss"

    # Determine if message should be displayed based on log level threshold.
    $shouldDisplay = Test-LogLevel -messageType $type -configuredLevel $Script:configuredLogLevel

    # Add blank line before message if requested and not in log-only mode and meets log level threshold.
    if ($prependNewLine -and (-not ($Script:logOnly -eq "enabled")) -and $shouldDisplay) {
        Write-Host ""
    }

    # Display message to console with color coding (unless suppressed, in log-only mode, or below log level threshold).
    if (-not $suppressOutputToScreen -and $Script:logOnly -ne "enabled" -and $shouldDisplay) {
        Write-Host -ForegroundColor $messageColor "[$type] $message"
    }

    # Add blank line after message if requested and not in log-only mode and meets log level threshold.
    if ($appendNewLine -and (-not ($Script:logOnly -eq "enabled")) -and $shouldDisplay) {
        Write-Host ""
    }

    # Write message to log file (unless suppressed).
    if (-not $suppressOutputToFile) {
        $logContent = '[' + $timeStamp + '] ' + '(' + $type + ')' + ' ' + $message
        try {
            Add-Content -ErrorVariable ErrorMessage -Path $Script:LogFile $logContent
        }
        catch {
            # Handle log file write failures gracefully.
            Write-Host "Failed to add content to log file $Script:LogFile."
            Write-Host $errorMessage
        }
    }
}
Function Show-Version {

    <#
        .SYNOPSIS
        Displays or logs the version of the VCF.Powershell.Toolbox module.

        .DESCRIPTION
        The Show-Version function displays or logs the current version of the
        VCF.Powershell.Toolbox module. When called without the -silence parameter,
        it displays the version to the console. With -silence, it only logs the
        version to the log file for audit purposes.

        The version is retrieved from the module manifest (VCF.Powershell.Toolbox.psd1).

        .PARAMETER silence
        When specified, suppresses console output and only logs the version to the log file.
        This is useful for automated scenarios where console output should be minimized
        while maintaining audit trail in logs.

        .EXAMPLE
        Show-Version

        Displays the module version to the console and logs it to the file.
        Output: "VCF.Powershell.Toolbox Module Version: 1.0.0.2"

        .EXAMPLE
        Show-Version -silence

        Logs the module version to the file only without console output.

        .NOTES
        This function is typically called during environment setup to record
        the module version in log files for troubleshooting purposes.
    #>

    Param(
        [Parameter(Mandatory = $false)] [ValidateNotNullOrEmpty()] [Switch]$silence
    )

    Write-LogMessage -type DEBUG -message "Entered Show-Version function..."

    # Get the module version from the loaded module manifest
    $moduleVersion = "Unknown"
    try {
        $manifestPath = Join-Path -Path $PSScriptRoot -ChildPath "VCF.Powershell.Toolbox.psd1"

        if (Test-Path $manifestPath) {
            $manifest = Import-PowerShellDataFile -Path $manifestPath -ErrorAction SilentlyContinue
            if ($manifest -and $manifest.ModuleVersion) {
                $moduleVersion = $manifest.ModuleVersion
            }
        } else {
            # Fallback: Try to get version from loaded module
            $loadedModule = Get-Module -Name "VCF.Powershell.Toolbox" -ErrorAction SilentlyContinue
            if ($loadedModule) {
                $moduleVersion = $loadedModule.Version
            }
        }
    } catch {
        Write-LogMessage -type DEBUG -message "Unable to retrieve module version: $_"
    }

    if (-not $silence) {
        Write-LogMessage -type INFO -message "VCF.Powershell.Toolbox Module Version: $moduleVersion"
    } else {
        Write-LogMessage -type DEBUG -message "VCF.Powershell.Toolbox Module Version: $moduleVersion"
    }
}
Function Get-EnvironmentSetup {

    <#
        .SYNOPSIS
        The function Get-EnvironmentSetup logs user environment details.

        .DESCRIPTION
        The function facilitates troubleshooting by populating each day's log files with useful runtime details.

        .EXAMPLE
        Get-EnvironmentSetup

        .OUTPUTS
        None
        This function does not return a value. It logs environment setup information.
    #>

    Write-LogMessage -type DEBUG -message "Entered Get-EnvironmentSetup function..."

    # Get PowerShell version information.
    $powerShellRelease = $($PSVersionTable.PSVersion).ToString()

    # Check for installed PowerCLI modules (VCF and VMware versions).
    $vcfPowerCliRelease = (Get-Module -ListAvailable -Name VCF.PowerCLI -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1).Version
    $vmwarePowerCliRelease = (Get-Module -ListAvailable -Name VMware.PowerCLI -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1).Version

    # Start with basic OS information from PowerShell automatic variables.
    $operatingSystem = $($PSVersionTable.OS)

    # Enhanced macOS information - sw_vers provides more user-friendly OS details than Darwin kernel info.
    if ($IsMacOS) {
        try {
            $macOsName = (sw_vers --productName)
            $macOsRelease = (sw_vers --productVersion)
            $macOsVersion = "$macOsName $macOsRelease"
        } catch [Exception] {
            # If sw_vers fails, we'll fall back to the basic OS info from $PSVersionTable.
        }
    }
    if ($macOsVersion) {
        $operatingSystem = $macOsVersion
    }

    # Enhanced Windows information - Get-ComputerInfo provides more detailed OS information.
    if ($IsWindows) {
        try {
            $windowsProductInformation = (Get-ComputerInfo -ProgressAction SilentlyContinue) | Select-Object OSName,OSVersion
            $windowsVersion = "$($windowsProductInformation.OSName) $($windowsProductInformation.OSVersion)"
        } catch [Exception] {
            # If Get-ComputerInfo fails, we'll fall back to the basic OS info from $PSVersionTable.
        }
    }
    if ($windowsVersion) {
        $operatingSystem = $windowsVersion
    }

    Show-Version -silence

    Write-LogMessage -type DEBUG -message "Client PowerShell version is $powerShellRelease"

    if ($vcfPowerCliRelease) {
        Write-LogMessage -type DEBUG -message "Client VCF.PowerCLI version is $vcfPowerCliRelease."
    }
    if ($vmwarePowerCliRelease) {
        Write-LogMessage -type DEBUG -message "Client VMware.PowerCLI version is $vmwarePowerCliRelease."
    }
    if (-not $vcfPowerCliRelease -and -not $vmwarePowerCliRelease) {
        Write-LogMessage -type ERROR -message "Client PowerCLI not installed. Please install VCF.PowerCLI or VMware.PowerCLI module."
        exit 1
    }

    Write-LogMessage -type DEBUG -message "Client Operating System is $operatingSystem"
}
Function New-LogFile {

    <#
        .SYNOPSIS
        Creates a log file with automatic directory structure and environment logging.

        .DESCRIPTION
        The New-LogFile function establishes the logging infrastructure for the VCF PowerShell
        Toolbox by creating a timestamped log file in a specified directory. The function creates
        one log file using the format mm-dd-yyyy, ensuring logs are organized chronologically.
        If the log directory doesn't exist, it will be created automatically. When a new log file
        is created, the function automatically calls Get-EnvironmentSetup to record system
        information for troubleshooting purposes.

        The function sets the following script-scoped variables:
        - $Script:logFolder: Path to the log directory
        - $Script:logFile: Full path to the current log file

        .PARAMETER prefix
        Specifies the prefix for the log file name. The final log file will be named
        "{Prefix}-{mm-dd-yyyy}.log". Default value is "VCF.PS.Toolbox".

        .PARAMETER directory
        Specifies the directory name where log files will be stored, relative to the script root.
        The directory will be created if it doesn't exist. Default value is "logs".

        .EXAMPLE
        New-LogFile
        Creates a log file with default settings: "logs/VCF.PS.Toolbox-01-15-2024.log"

        .EXAMPLE
        New-LogFile -directory "audit" -prefix "SecurityAudit"
        Creates a log file: "audit/SecurityAudit-01-15-2024.log"

        .NOTES
        This function should be called before any Write-LogMessage calls to ensure the log
        infrastructure is properly initialized. The function will exit the script if it
        cannot create the required log directory.
    #>

    Param(
        [Parameter(Mandatory = $false)] [ValidateNotNullOrEmpty()] [String]$directory = "logs",
        [Parameter(Mandatory = $false)] [ValidateNotNullOrEmpty()] [String]$prefix = "VCF.Powershell.Toolbox"
    )

    # Generate timestamp for daily log file naming (yyyy-MM-dd format)
    $fileTimeStamp = Get-Date -Format "yyyy-MM-dd"

    # Set script-scoped variables for log directory and file paths.
    $Script:logFolder = Join-Path -Path $PSScriptRoot -ChildPath $directory
    $Script:logFile = Join-Path -Path $Script:logFolder -ChildPath "$prefix-$fileTimeStamp.log"

    # Create log directory if it doesn't exist.
    if (-not (Test-Path -Path $Script:logFolder -PathType Container) ) {
        Write-Information "LogFolder not found, creating $Script:logFolder" -InformationAction Continue
        New-Item -ItemType Directory -Path $Script:logFolder | Out-Null
        if (-not $?) {
            Write-Information "Failed to create directory $Script:logFile. Exiting." -InformationAction Continue
            exit 1
        }
    }

    # Create the log file if it doesn't exist for today.
    # When creating a new log file, automatically capture environment details for troubleshooting.
    if (-not (Test-Path $Script:logFile)) {
        New-Item -type File -Path $Script:logFile | Out-Null
        Get-EnvironmentSetup
    }
}
Function Start-ProcessTimer {

    <#
        .SYNOPSIS
        Initializes and starts a high-precision stopwatch for operation timing.

        .DESCRIPTION
        The Start-ProcessTimer function creates and starts a System.Diagnostics.Stopwatch
        object for measuring elapsed time of operations. This provides a consistent way
        to begin timing across the VCF PowerShell Toolbox functions. The returned stopwatch
        object should be used with the Stop-ProcessTimer function for consistent logging.

        .OUTPUTS
        System.Diagnostics.Stopwatch
        A started stopwatch object that can be used to measure elapsed time.

        .EXAMPLE
        $timer = Start-ProcessTimer
        # Perform some operation
        Stop-ProcessTimer -timer $timer -operation "Data processing" -interval "Seconds"

        .NOTES
        This function is designed to be paired with Stop-ProcessTimer for complete
        timing functionality with automatic logging.
    #>

    return [System.Diagnostics.Stopwatch]::StartNew()
}
Function Stop-ProcessTimer {
    <#
        .SYNOPSIS
        Stops a stopwatch timer and logs the elapsed time for the specified operation.

        .DESCRIPTION
        The Stop-ProcessTimer function stops a System.Diagnostics.Stopwatch object and
        automatically logs the elapsed time to the log file. The elapsed time is calculated
        and rounded to 2 decimal places based on the specified interval (milliseconds,
        seconds, or minutes). This provides consistent timing and logging across all
        VCF PowerShell Toolbox operations.

        .PARAMETER timer
        The System.Diagnostics.Stopwatch object to stop. This should be a stopwatch
        that was started using the Start-ProcessTimer function.

        .PARAMETER operation
        A descriptive name for the operation that was being timed. This will be included
        in the log message for identification purposes.

        .PARAMETER interval
        The time unit for reporting the elapsed time. Valid values are:
        - "Milliseconds": Reports time in milliseconds (ms)
        - "Seconds": Reports time in seconds (s)
        - "Minutes": Reports time in minutes (min)

        .EXAMPLE
        $timer = Start-ProcessTimer
        # Perform vCenter connection
        Stop-ProcessTimer -timer $timer -operation "vCenter connection" -interval "Seconds"
        # Logs: "vCenter connection took 2.35 Seconds to complete."

        .EXAMPLE
        $timer = Start-ProcessTimer
        # Perform quick operation
        Stop-ProcessTimer -timer $timer -operation "API call" -interval "Milliseconds"
        # Logs: "API call took 250.75 Milliseconds to complete."

        .NOTES
        The elapsed time is automatically logged to the file (not displayed on console).
        All timing measurements are rounded to 2 decimal places for consistency.
    #>

    Param(
        [Parameter(Mandatory = $true)] [ValidateSet("Milliseconds","Seconds","Minutes")] [String]$interval,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [String]$operation,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [System.Diagnostics.Stopwatch]$timer
    )

    # Stop the stopwatch to capture final elapsed time.
    $timer.Stop()

    # Calculate elapsed time based on requested interval and round to 2 decimal places.
    switch ($interval) {
        "Milliseconds" {
            $elapsedInterval = [math]::Round(($timer.elapsed.totalMilliseconds), 2)
        }
        "Seconds" {
            $elapsedInterval = [math]::Round(($timer.elapsed.totalSeconds), 2)
        }
        "Minutes" {
            $elapsedInterval = [math]::Round(($timer.elapsed.totalMinutes), 2)
        }
    }

    # Log the timing result (suppressed from console output).
    Write-LogMessage -type INFO -suppressOutputToScreen -message "$operation took $elapsedInterval $interval to complete."
}
Function ConvertFrom-JsonSafely {

    <#
        .SYNOPSIS
        Safely loads and validates JSON content from a file with comprehensive error handling.

        .DESCRIPTION
        The ConvertFrom-JsonSafely function provides a robust way to load JSON files with
        built-in validation and error handling. The function reads the file content, removes
        empty lines that could cause JSON parsing issues, and converts the content to a
        PowerShell object. If JSON validation fails, the function logs detailed error
        information including the file path and specific parsing error, then exits the
        script to prevent further execution with invalid data.

        This function standardizes JSON loading across the VCF PowerShell Toolbox and
        ensures consistent error reporting for troubleshooting.

        .PARAMETER jsonFilePath
        The full path to the JSON file to load and parse. The file must exist and
        contain valid JSON content.

        .EXAMPLE
        $Config = ConvertFrom-JsonSafely -jsonFilePath "C:\configs\settings.json"
        Loads application settings from a JSON file with error handling.

        .NOTES
        This function will terminate script execution (exit) if JSON parsing fails.
        Empty lines are automatically filtered out before JSON parsing to handle
        files that may have formatting issues.
    #>

    Param(
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [String]$jsonFilePath
    )

    Write-LogMessage -type DEBUG -message "Entered ConvertFrom-JsonSafely function..."

    try {
        # Read file content, filter out empty lines, and convert from JSON,
        # Empty line filtering prevents JSON parsing issues with poorly formatted files,
        return (Get-Content $jsonFilePath) | Select-String -Pattern "^\s*$" -NotMatch | ConvertFrom-Json

    }
    catch {
        # Handle JSON parsing errors with detailed, user-friendly logging.
        $errorMessage = $_.Exception.Message

        Write-LogMessage -type ERROR -message "JSON validation failed for file: $jsonFilePath"
        Write-Host ""

        # Extract the specific JSON error and location
        if ($errorMessage -match "Bad JSON escape sequence: \\([A-Za-z])\..*'([^']+)'.*line (\d+).*position (\d+)") {
            $badChar = $matches[1]
            $jsonPath = $matches[2]
            $lineNum = $matches[3]
            $position = $matches[4]

            Write-LogMessage -type ERROR -message "Invalid escape sequence: '\$badChar' in JSON property '$jsonPath'"
            Write-LogMessage -type ERROR -message "Location: Line $lineNum, Position $position"
            Write-Host ""
            Write-LogMessage -type ERROR -message "Common causes:"
            Write-LogMessage -type ERROR -message "  1. Windows file paths must use forward slashes (/) or escaped backslashes (\\\\)"
            Write-LogMessage -type ERROR -message "     Example: `"C:/Users/Admin/file.yml`" or `"C:\\\\Users\\\\Admin\\\\file.yml`""
            Write-LogMessage -type ERROR -message "  2. Backslash (\) is a special character in JSON and must be escaped"
            Write-Host ""
            Write-LogMessage -type ERROR -message "Please correct the JSON syntax in '$jsonFilePath' at line $lineNum and try again."
        }
        elseif ($errorMessage -match "Conversion from JSON failed with error: (.+?)\. Path '([^']+)'.*line (\d+).*position (\d+)") {
            $jsonError = $matches[1]
            $jsonPath = $matches[2]
            $lineNum = $matches[3]
            $position = $matches[4]

            Write-LogMessage -type ERROR -message "JSON parsing error: $jsonError"
            Write-LogMessage -type ERROR -message "Property: '$jsonPath'"
            Write-LogMessage -type ERROR -message "Location: Line $lineNum, Position $position"
            Write-Host ""
            Write-LogMessage -type ERROR -message "Please correct the JSON syntax in '$jsonFilePath' and try again."
        }
        else {
            # Fallback for unexpected error formats
            Write-LogMessage -type ERROR -message "JSON parsing error: $errorMessage"
        }

        # Exit script execution to prevent continuing with invalid data.
        exit 1
    }
}
Function New-ChoiceMenu {

    <#
        .SYNOPSIS
        Presents an interactive yes/no choice menu to the user with a configurable default.

        .DESCRIPTION
        The New-ChoiceMenu function creates a standardized interactive prompt that presents
        the user with a yes/no decision. The function uses PowerShell's built-in choice
        prompt functionality to provide a consistent user experience across the VCF PowerShell
        Toolbox. The user can select options using Y/N keys or simply press Enter to accept
        the default choice.

        The function returns an integer value (0 for Yes, 1 for No) that can be used in
        conditional logic to determine the user's decision.

        .PARAMETER question
        The question or prompt text to display to the user. This should be a clear,
        concise question that can be answered with yes or no.

        .PARAMETER defaultAnswer
        The default answer that will be selected if the user presses Enter without
        making a selection. Valid values are "Yes" or "No" (case-sensitive).

        .OUTPUTS
        System.Int32
        Returns 0 if the user selects Yes, or 1 if the user selects No.

        .EXAMPLE
        $decision = New-ChoiceMenu -question "Would you like to create the log folder?" -defaultAnswer "Yes"
        if ($decision -eq 0) {
            Write-Host "User chose Yes"
        } else {
            Write-Host "User chose No"
        }

        .EXAMPLE
        $continue = New-ChoiceMenu -question "Do you want to proceed with the operation?" -defaultAnswer "No"
        Creates a prompt with "No" as the default, requiring explicit user confirmation.

        .NOTES
        This function requires an interactive PowerShell session and will not work in
        non-interactive or headless environments. The default answer parameter is
        case-sensitive and must be exactly "Yes" or "No".
    #>

    Param(
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [String]$defaultAnswer,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [String]$question
    )

    # Create a collection to hold the choice options
    $choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]

    # Add Yes and No options with keyboard shortcuts (&Y and &N)
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes', "Yes"))
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No', "No"))

    # Set the default choice based on the DefaultAnswer parameter
    # Index 0 = Yes, Index 1 = No
    # Note: $title is intentionally $null as we use $question for the prompt text
    $title = $null
    if ($defaultAnswer -eq "Yes") {
        $decision = $host.UI.PromptForChoice($title, $question, $choices, 0)
    }
    else {
        $decision = $host.UI.PromptForChoice($title, $question, $choices, 1)
    }

    return $decision
}
Function Show-AnyKey {

    <#
        .SYNOPSIS
        Pauses script execution and waits for user to press any key before continuing.

        .DESCRIPTION
        The Show-AnyKey function provides a standardized way to pause script execution
        and wait for user acknowledgment before proceeding. This is commonly used after
        displaying information, completing operations, or before returning to menus.
        The function only operates in interactive mode and is automatically bypassed
        when the script is running in headless mode.

        The function displays a yellow-colored prompt message and captures any keystroke
        without echoing it to the console, providing a clean user experience.

        .EXAMPLE
        Show-AnyKey
        Displays "Press any key to continue..." and waits for user input.

        .NOTES
        This function checks the $headless variable and only prompts for input when
        $headless equals "disabled". In headless mode, the function returns immediately
        without any user interaction, allowing scripts to run unattended.

        The function uses RawUI.ReadKey with 'NoEcho,IncludeKeyDown' options to capture
        keystrokes without displaying them on the console.
    #>

    # Only prompt for user input when not in headless mode.
    if (-not $Script:headless -or $Script:headless -eq "disabled") {
        Write-Host "`nPress any key to continue...`n" -ForegroundColor Yellow;
        # Capture keystroke without echoing to console
        $host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') | Out-Null
    }
}
Function Test-EmptyValue {

     <#
        .SYNOPSIS
        Validates that a string value is not null or empty, exiting the script if validation fails.

        .DESCRIPTION
        The Test-EmptyValue function provides a standardized way to validate required string
        parameters or variables throughout the VCF PowerShell Toolbox. When a value is found
        to be null or empty, the function logs an error message identifying the specific field
        that failed validation and immediately terminates script execution with exit code 1.

        This function is designed to be used for critical validations where continuing execution
        with missing data would lead to unpredictable results or failures. It provides consistent
        error reporting and ensures that scripts fail fast when required data is missing.

        .PARAMETER fieldName
        A descriptive name for the field or variable being validated. This name will be included
        in the error message to help identify which specific field failed validation.

        .PARAMETER value
        The string value to validate. The parameter allows empty strings to be passed (using
        [AllowEmptyString()]) so that the function can properly detect and report empty values.

        .EXAMPLE
        Test-EmptyValue -fieldName "Username" -value $username
        Validates that the Username variable is not null or empty, logging "Username is empty." if validation fails.

    #>

   Param(
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [String]$fieldName,
        [Parameter(Mandatory = $true)] [AllowEmptyString()] [String]$value
    )

    if ([String]::IsNullOrEmpty($value)) {
        Write-LogMessage -type ERROR -message "$fieldName is empty."
        exit 1
    }
}
Function Get-InteractiveInput {

    <#
        .SYNOPSIS
        Prompts the user for input and returns the value.

        .DESCRIPTION
        The Get-InteractiveInput function provides a standardized way to prompt the user for input and return the value.
        This function is designed to be used for interactive input throughout the VCF PowerShell Toolbox.

        .PARAMETER promptMessage
        The message to display to the user.

        .PARAMETER asSecureString
        When specified, the function will prompt the user for input as a secure string.

        .OUTPUTS
        System.String
        Returns the user's input as a string.

        .EXAMPLE
        $username = Get-InteractiveInput -promptMessage "Enter your username:"
        Prompts the user for a username and returns the value.
    #>

    Param(
        [Parameter(Mandatory = $false)] [ValidateNotNullOrEmpty()] [Switch]$asSecureString,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [String]$promptMessage
    )

    do {
        if ($asSecureString) {
            $value = Read-Host $promptMessage -asSecureString
        } else {
            $value = Read-Host $promptMessage
        }
    } while ($value -eq "")

    return $value
}
Function Test-ArrayMissingProperties {

    <#
        .SYNOPSIS
        Checks for missing properties in objects within an array and returns detailed validation results.

        .DESCRIPTION
        The Test-ArrayMissingProperties function validates that all objects in an array contain
        the specified required properties. This function is useful for validating configuration
        data, API responses, or any collection of objects that should have a consistent schema.

        The function returns a comprehensive validation result that includes:
        - Overall validation status (pass/fail).
        - List of missing properties per object.
        - Summary of validation issues.
        - Detailed error information for troubleshooting.

        .PARAMETER array
        The array of objects to validate. Each object in the array will be checked for
        the presence of the required properties.

        .PARAMETER requiredProperties
        An array of property names that must be present in each object. Property names
        are case-sensitive and must match exactly.

        .PARAMETER arrayName
        A descriptive name for the array being validated, used in error messages and
        logging to help identify the source of validation failures.

        .PARAMETER stopOnFirstError
        When specified, the function will stop validation and return immediately upon
        finding the first missing property, rather than validating the entire array.

        .OUTPUTS
        System.Management.Automation.PSCustomObject
        Returns an object with the following properties:
        - isValid: Boolean indicating if all validations passed
        - MissingProperties: Array of objects detailing missing properties per item
        - ErrorCount: Total number of validation errors found
        - Summary: Human-readable summary of validation results.

        .EXAMPLE
        $users = @(
            @{ name = "John"; email = "john@example.com" },
            @{ name = "Jane" },
            @{ email = "bob@example.com" }
        )
        $result = Test-ArrayMissingProperties -array $users -requiredProperties @("name", "email") -arrayName "Users"

        if (-not $result.isValid) {
            return
        }

        .EXAMPLE
        $config = ConvertFrom-JsonSafely -jsonFilePath "config.json"
        $validationResult = Test-ArrayMissingProperties -array $config.servers -requiredProperties @("hostname", "username", "password") -arrayName "ServerConfiguration" -stopOnFirstError

        if (-not $validationResult.isValid) {
            return
        }

        .NOTES
        This function is designed to work with arrays of PSCustomObject, hashtables, or any
        objects that support property access via PSObject.Properties. The function logs
        detailed validation results and integrates with the VCF PowerShell Toolbox logging
        infrastructure for consistent error reporting.
    #>

    Param(
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [Array]$array,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [String]$arrayName,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [String[]]$requiredProperties,
        [Parameter(Mandatory = $false)] [ValidateNotNullOrEmpty()] [Switch]$stopOnFirstError
    )

    # Initialize validation result object
    $validationResult = [PSCustomObject]@{
        isValid = $true
        MissingProperties = @()
        ErrorCount = 0
        Summary = ""
    }

    Write-LogMessage -type INFO -message "Starting validation of $arrayName with $($array.count) items for properties: $($requiredProperties -join ', ')" -suppressOutputToScreen

    # Validate each object in the array
    for ($i = 0; $i -lt $array.count; $i++) {
        $currentObject = $array[$i]
        $missingProps = @()

        # Check each required property
        foreach ($property in $requiredProperties) {
            # Handle different object types (PSCustomObject, Hashtable, etc.)
            $hasProperty = $false

            if ($currentObject -is [System.Collections.Hashtable]) {
                $hasProperty = $currentObject.ContainsKey($property)
            } elseif ($currentObject.PSObject.Properties[$property]) {
                $hasProperty = $true
            }

            if (-not $hasProperty) {
                $missingProps += $property
                $validationResult.errorCount++
            }
        }

        # Record missing properties for this object
        if ($missingProps.count -gt 0) {
            $validationResult.isValid = $false
            $missingPropertyInfo = [PSCustomObject]@{
                Index = $i
                Missing = $missingProps
            }
            $validationResult.missingProperties += $missingPropertyInfo

            Write-LogMessage -type ERROR -appendNewLine -message "$arrayName item at index $i is missing required properties: $($missingProps -join ', ')"

            # Stop on first error if requested
            if ($stopOnFirstError) {
                break
            }
        }
    }

    # Generate summary message and log message
    if ($validationResult.isValid) {
        $validationResult.summary = "$arrayName validation passed. All $($array.count) item(s) contain required properties."
        Write-LogMessage -type INFO -suppressOutputToScreen -message $validationResult.summary
    } else {
        $affectedItems = $validationResult.missingProperties.count
        $validationResult.summary = "$arrayName validation failed. $affectedItems of $($array.count) items are missing required properties ($($validationResult.errorCount) total missing properties)."
        Write-LogMessage -type ERROR -suppressOutputToScreen -message $validationResult.summary
    }

    return $validationResult
}