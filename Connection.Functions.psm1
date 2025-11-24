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
# VCF.Powershell.Toolbox - Connection Functions Module
#
# This module provides connection management functions for the VCF PowerShell Toolbox,
# enabling secure authentication and session management for VMware Cloud Foundation
# SDDC Manager and vCenter Server instances. These functions handle credential
# management, token-based authentication, connection health monitoring, and automatic
# reconnection capabilities.
#
# Key Features:
# - SDDC Manager authentication with JSON credential file support
# - Interactive and non-interactive (headless) authentication modes
# - Token expiration monitoring and automatic refresh
# - vCenter Server connection management with PSCredential support
# - Connection health validation and auto-reconnection
# - Version detection and validation for SDDC Manager and vCenter
# - Comprehensive error handling and logging integration
#
# Last modified: 2025-11-20
#
Function Connect-SddcManager {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'sddcManagerCredentialsJson')]

    <#
        .SYNOPSIS
        Establishes an authenticated connection to VMware Cloud Foundation SDDC Manager.

        .DESCRIPTION
        The Connect-SddcManager function provides comprehensive connection management for SDDC Manager,
        supporting both interactive and non-interactive authentication modes. It offers:

        - JSON credential file support for automated/headless operations
        - Interactive credential prompting when JSON files are unavailable
        - Automatic credential file creation for future non-interactive use
        - Token-based authentication with session management
        - Comprehensive error handling for various connection failure scenarios
        - Reconnection capability using cached credentials

        The function handles the complete authentication workflow:
        1. Credential acquisition (JSON file or interactive prompts)
        2. Connection attempt with detailed error handling
        3. Optional credential file creation for future use
        4. Session validation and token management

        Administrative privileges are required on the SDDC Manager for successful authentication.

        .PARAMETER sddcManagerCredentialsJson
        Path to the JSON file containing SDDC Manager credentials. The file should contain:
        - sddcManagerFqdn: Fully qualified domain name of the SDDC Manager
        - sddcManagerUserName: SSO or federated username
        - sddcManagerPassword: User password

        If the file doesn't exist, the function will prompt for credentials interactively
        and optionally create the file for future use. Default: "SddcManagerCredentials.Json"

        Note: This parameter is a file path (String), not the credential itself. The actual
        credentials are stored securely in the file and handled as PSCredential/SecureString
        during processing.

        .PARAMETER reconnect
        Forces reconnection using previously cached credentials (stored in script-scoped variables).
        This is useful when tokens have expired or connections have been lost. Bypasses credential
        prompting and file operations when cached credentials are available.

        .EXAMPLE
        Connect-SddcManager

        Connects using default credential file or prompts for credentials if file doesn't exist.
        Offers to save credentials to JSON file after successful connection.

        .EXAMPLE
        Connect-SddcManager -sddcManagerCredentialsJson "ProductionCredentials.json"

        Connects using credentials from a custom JSON file path.

        .EXAMPLE
        Connect-SddcManager -reconnect

        Reconnects using cached credentials from a previous session, useful for token refresh.

        .NOTES
        - Requires VCF.PowerCLI or VMware.PowerCLI module
        - Creates script-scoped variables for connection management
        - Automatically initializes logging system via New-LogFile
        - Supports SSL certificate validation and troubleshooting
        - Handles various authentication error scenarios with descriptive messages
        - Can create credential files with appropriate security warnings
    #>

    Param(
        [Parameter(Mandatory = $false)] [ValidateNotNullOrEmpty()] [Switch]$reconnect,
        [Parameter(Mandatory = $false)] [ValidateNotNullOrEmpty()] [String]$sddcManagerCredentialsJson = "SddcManagerCredentials.Json"
    )

    # This ensures all actions are properly logged.
    New-LogFile

    # Handle reconnection scenario using cached credentials
    # This is typically used when tokens have expired but credentials are still valid
    if ($reconnect) {
        # Verify that all required cached credentials are available
        if ($Script:sddcManagerFqdn -and $Script:sddcManagerUserName -and $Script:sddcManagerPassword) {
            # Attempt reconnection using cached credentials with error suppression
            $connectedToSddcManager = Connect-VcfSddcManagerServer -Server $Script:sddcManagerFqdn -User $Script:sddcManagerUserName -Password $Script:sddcManagerPassword -ErrorAction SilentlyContinue
        }
        # If reconnection successful, log and exit early
        if ($connectedToSddcManager) {
            Write-LogMessage -type DEBUG -message "Created new access token for $Script:sddcManagerFqdn"
            return
        }
    }

    # Begin main authentication workflow.
    # Check if credentials JSON file exists for automated authentication.
    $sddcManagerCredentialsJsonFileExists = Test-Path $sddcManagerCredentialsJson

    if ($sddcManagerCredentialsJsonFileExists) {
        Write-LogMessage -type INFO -prependNewLine -appendNewLine -message "Detected JSON input file `"$sddcManagerCredentialsJson`"."

        # Convert the JSON file to a PowerShell object.
        $sddcManagerCredentialsObject = ConvertFrom-JsonSafely -jsonFilePath $sddcManagerCredentialsJson

        # Assign the properties to the script variables.
        $Script:sddcManagerFqdn = $sddcManagerCredentialsObject.sddcManagerFqdn
        $Script:sddcManagerUserName = $sddcManagerCredentialsObject.sddcManagerUserName
        $Script:sddcManagerPassword = $sddcManagerCredentialsObject.sddcManagerPassword

        # Validate that all required properties exist in the JSON file.
        # This prevents runtime errors and provides clear feedback about missing fields.
        # $JsonProperties = @('sddcManagerFqdn', 'sddcManagerUserName', 'sddcManagerPassword')

        $results = Test-ArrayMissingProperties -array $sddcManagerCredentialsObject -requiredProperties @('sddcManagerFqdn', 'sddcManagerUserName', 'sddcManagerPassword') -arrayName "$sddcManagerCredentialsJson"

        # If the JSON file is invalid, exit the function.
        if (-not $results.IsValid) {
            return
        }

        # Validate that all required properties are not empty.
        Test-EmptyValue -value $Script:sddcManagerFqdn -fieldName "sddcManagerFqdn"
        Test-EmptyValue -value $Script:sddcManagerUserName -fieldName "sddcManagerUserName"
        Test-EmptyValue -value $Script:sddcManagerPassword -fieldName "sddcManagerPassword"

    } else {
        # Handle case where JSON credentials file doesn't exist
        # Check if running in silent/headless mode - this requires credentials file
        if ($Script:logOnly -eq "enabled") {
            # Silent mode requires JSON credentials - cannot prompt for input
            Write-Host "Option -silence cannot be used when JSON credential file not present." -ForegroundColor Red
            Write-LogMessage -type ERROR -message "Option -silence cannot be used when JSON credential file not present."
            exit
        }

        # Inform user that credentials file was not found and interactive input is required
        Write-LogMessage -type WARNING -appendNewLine -message "JSON SDDC Credentials input file `"$sddcManagerCredentialsJson`" not detected."
        Write-LogMessage -type WARNING -suppressOutputToScreen -message "Could not locate JSON credentials file `"$sddcManagerCredentialsJson`" ."
        Write-LogMessage -type INFO -appendNewLine -message "Please enter your connection details at the prompt."

        # Interactive credential collection with validation loops
        # Ensure all required credentials are provided before proceeding

        # Collect SDDC Manager FQDN with validation.
        $Script:sddcManagerFqdn =  Get-InteractiveInput -promptMessage "Enter your SDDC Manager FQDN"
        $Script:sddcManagerUserName = Get-InteractiveInput -promptMessage "Enter your SDDC Manager SSO username"
        $Script:sddcManagerPassword =  Get-InteractiveInput -promptMessage "Enter your SDDC Manager SSO password" -asSecureString
    }

    # Log connection attempt (to file only for clean console output)
    Write-LogMessage -type DEBUG -message "Attempting to connect to SDDC Manager `"$Script:sddcManagerFqdn`" with user `"$Script:sddcManagerUserName`"..."

    # Enable debug output for connection troubleshooting
    $debugPreference = 'Continue'

    # Attempt connection with error suppression to handle errors gracefully.  Write any errors to $errorMessage for parsing.
    $connectedToSddcManager = Connect-VcfSddcManagerServer -Server $Script:sddcManagerFqdn -User $Script:sddcManagerUserName -Password $Script:sddcManagerPassword -ErrorAction SilentlyContinue -ErrorVariable ErrorMessage

    # Check connection result and handle any errors
    if (-not $connectedToSddcManager) {
        # Connection failed - error handling will follow
        # Debug information can be added here if needed for troubleshooting
    }

    # Comprehensive error handling for various connection failure scenarios
    # Each error pattern provides specific guidance for resolution
    # Using switch with regex matching for better readability and maintainability

    switch -Regex ($errorMessage) {
        "IDENTITY_UNAUTHORIZED_ENTITY" {
            # Authentication failed - invalid credentials
            Write-LogMessage -type ERROR -message "Failed to connect to SDDC Manager `"$Script:sddcManagerFqdn`" using username `"$Script:sddcManagerUserName`". Please check your credentials."
            break
        }
        "nodename nor servname provided" {
            # DNS resolution failed - FQDN cannot be resolved
            Write-LogMessage -type ERROR -message "Cannot resolve SDDC Manager `"$Script:sddcManagerFqdn`". If this is a valid SDDC Manager FQDN, please check your DNS settings."
            break
        }
        "The requested URL <code>/v1/tokens</code> was not found on this Server" {
            # API endpoint not found - likely not an SDDC Manager or service issue
            Write-LogMessage -type ERROR -message "SDDC Manager `"$Script:sddcManagerFqdn`" did not return a valid response. Please check that `"$Script:sddcManagerFqdn`" is a valid SDDC Manager FQDN and if its services are healthy."
            break
        }
        "The SSL connection could not be established\." {
            # SSL/TLS certificate issues
            Write-LogMessage -type ERROR -message "SSL Connection error to SDDC Manager `"$Script:sddcManagerFqdn`". Please check that SDDC Manager has a CA signed certificate or Powershell trusts insecure certificates."
            break
        }
        "Permission not found" {
            # User lacks required permissions
            Write-LogMessage -type ERROR -message "Username `"$Script:sddcManagerUserName`" does not have access to SDDC Manager."
            break
        }
        "not recognized as a name of a cmdlet" {
            # PowerCLI cmdlet not found - installation issue
            Write-LogMessage -type ERROR -message "Could not find PowerCLI cmdlet Connect-VcfSddcManagerServer. Your PowerCLI installation may be incomplete."
            break
        }
        "but the module could not be loaded" {
            # PowerCLI module loading failed - environment issue
            Write-LogMessage -type ERROR -message "VMware.Sdk.Vcf.SddcManager, the module containing the required Connect-VcfSddcManagerServer PowerCLI cmdlet could not be loaded.  Your PowerCLI environment may not be configured correctly.  Please investigate before re-running this script."
            break
        }
        Default {
            # Catch-all for any other unexpected errors (only if $errorMessage has content)
            if ($errorMessage) {
                Write-LogMessage -type ERROR -message "Error Message: $errorMessage"
            }
        }
    }

    # Handle connection failure scenarios and provide recovery options.
    if (-not $connectedToSddcManager) {
        if ($sddcManagerCredentialsJsonFileExists) {
            # If using JSON credentials file, exit with instructions to fix the file
            Write-LogMessage -type ERROR -prependNewLine -message "Please confirm your SDDC Manager FQDN and user credentials in $sddcManagerCredentialsJson and return to the script."
            return
        }

        # For interactive mode, offer to retry with new credentials
        $decision = New-ChoiceMenu -question "Would you like to re-enter your SDDC Manager FQDN and user credentials?" -defaultAnswer "Yes"

        # Handle user's decision on retry
        if ($decision -eq 0) {
            # User chose to retry - recursively call function for new attempt.
            Connect-SddcManager
        } else {
            # User chose not to retry - exit the connection attempt.
            break
        }
    } else {
        # Connection successful - log success and version information
        Write-LogMessage -type INFO -appendNewLine -message "Successfully connected to SDDC Manager `"$Script:sddcManagerFqdn`" as `"$Script:sddcManagerUserName`"."
        Write-LogMessage -type DEBUG -message "SDDC Manager `"$Script:sddcManagerFqdn`" version is `"$($Global:defaultSddcManagerConnections.ProductVersion)`"."

        # Offer to create credentials file for future non-interactive use
        # This only occurs for interactive sessions where credentials were manually entered
        if (-not $sddcManagerCredentialsJsonFileExists) {
            # Inform user about credential file benefits and security considerations
            Write-LogMessage -type ADVISORY -appendNewLine -message "Your SDDC Manager login credentials may be saved to a file to allow non-interactive login in the future. This is not required, and the file may be safely removed at any time."

            # Prompt user for credential file creation (default to No for security)
            $decision = New-ChoiceMenu -question "Would you like to save your SDDC login credentials in a JSON file?" -defaultAnswer "No"

            if ($decision -eq 0) {
                # User chose to save credentials
                Write-LogMessage -type DEBUG -message "User chose to save SDDC Manager credentials to JSON file."
                Write-LogMessage -type INFO -appendNewLine -message "Writing credentials to `"$sddcManagerCredentialsJson`"..."

                # Securely decode the password from SecureString for JSON storage
                # This is necessary but should be handled carefully for security
                $decodedPasswordInterimStep = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($Script:sddcManagerPassword)
                $decodedSddcManagerPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($decodedPasswordInterimStep)
                # Clear the interim memory allocation for security
                [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($decodedPasswordInterimStep)

                # Create JSON structure with all required credentials
                $jsonHashTable = @{
                    'sddcManagerFqdn' = $Script:sddcManagerFqdn
                    'sddcManagerUserName' = $Script:sddcManagerUserName
                    'sddcManagerPassword' = $decodedSddcManagerPassword
                }

                # Convert to JSON and save to file
                $jsonOutput = $jsonHashTable | ConvertTo-Json
                Set-Content -Path $sddcManagerCredentialsJson $jsonOutput
            } else {
                # User chose not to save credentials
                Write-LogMessage -type DEBUG -message "User chose not to save SDDC Manager credentials to JSON file."
            }
        }
    }
}
Function Disconnect-SddcManager {

    <#
        .SYNOPSIS
        Safely disconnects from SDDC Manager with optional user confirmation and logging control.

        .DESCRIPTION
        The Disconnect-SddcManager function provides a controlled way to terminate SDDC Manager
        connections with various operation modes:

        - Interactive mode: Prompts user for confirmation before disconnecting
        - Automatic mode: Disconnects without prompts (useful for cleanup scenarios)
        - Silent mode: Suppresses console output while maintaining file logging
        - Custom prompts: Allows override of default confirmation messages

        The function is typically called in these scenarios:
        - Automatic cleanup when exiting interactive scripts
        - User-initiated disconnection in interactive mode
        - Switching between different SDDC Manager instances
        - Cleanup in automated/headless operations

        The function validates connection state before attempting disconnection and
        provides appropriate feedback based on the operation mode.

        .PARAMETER overrideQuestion
        Custom confirmation message to display instead of the default disconnect prompt.
        This allows context-specific prompts (e.g., "Switch to different SDDC Manager?").
        Only used when NoPrompt is not specified.

        .PARAMETER noPrompt
        Bypasses user confirmation and disconnects immediately. Useful for:
        - Automated cleanup operations.
        - Error handling scenarios.
        - Script termination sequences.

        .PARAMETER silence
        Suppresses console output while maintaining file logging. The disconnect
        operation and results are still logged to file for audit purposes.

        .EXAMPLE
        Disconnect-SddcManager

        Standard interactive disconnect with default confirmation prompt.

        .EXAMPLE
        Disconnect-SddcManager -noPrompt

        Immediate disconnect without user confirmation, typically used in cleanup.

        .EXAMPLE
        Disconnect-SddcManager -overrideQuestion "Switch to different SDDC Manager?"

        Custom confirmation message for specific use cases.

        .EXAMPLE
        Disconnect-SddcManager -noPrompt -silence

        Silent disconnect for automated operations with file-only logging.

        .NOTES
        - Checks connection state before attempting disconnection.
        - Maintains connection information for logging after disconnection.
        - Supports both interactive and automated operation modes.
        - Always logs disconnection attempts and results to file.
    #>

    Param(
        [Parameter(Mandatory = $false)] [ValidateNotNullOrEmpty()] [Switch]$noPrompt,
        [Parameter(Mandatory = $false)] [ValidateNotNullOrEmpty()] [String]$overrideQuestion,
        [Parameter(Mandatory = $false)] [ValidateNotNullOrEmpty()] [Switch]$silence
    )

    # This ensures all actions are properly logged.
    New-LogFile

    # Check if there's an active SDDC Manager connection
    if (-not $Global:defaultSddcManagerConnections.IsConnected) {
        # No active connection found
        if (-not $silence) {
            Write-LogMessage -type INFO -message "No SDDC Manager connection detected."
        }
    } else {
        # Preserve SDDC Manager name for logging after disconnection
        # This is necessary because the connection object becomes unavailable after disconnect
        $Global:sddcManagerFqdn = $Global:defaultSddcManagerConnections.name

        # Handle user confirmation unless NoPrompt is specified
        if (-not $noPrompt) {
            if ($overrideQuestion) {
                # Use custom confirmation message if provided
                $decision = New-ChoiceMenu -question "$overrideQuestion" -defaultAnswer "No"
            } else {
                # Use standard disconnect confirmation
                $decision = New-ChoiceMenu -question "Would you like to disconnect from `"$Global:sddcManagerFqdn`"?" -defaultAnswer "No"
            }
        }

        # Execute disconnection if user confirmed or NoPrompt is specified
        if (($decision -eq 0) -or ($noPrompt)) {
            # Attempt disconnection using PowerCLI cmdlet
            Disconnect-VcfSddcManagerServer -Server $Global:defaultSddcManagerConnections.name

            # Check disconnection result and log appropriately
            if ($?) {
                # Disconnection successful
                if ($silence) {
                    # Silent mode - log to file only
                    Write-LogMessage -type DEBUG -message "Successfully disconnected from SDDC Manager `"$Global:sddcManagerFqdn`"."
                } else {
                    # Normal mode - display success message
                    Write-LogMessage -type INFO -appendNewLine -message "Successfully disconnected from SDDC Manager `"$Global:sddcManagerFqdn`"."
                }
            } else {
                # Disconnection failed - always show error regardless of silence mode
                Write-LogMessage -type ERROR -message "Failed to disconnect from SDDC Manager `"$Global:sddcManagerFqdn`"."
            }
        } else {
            # User chose not to disconnect
            Write-LogMessage -type DEBUG -message "User chose not to disconnect from `"$Global:sddcManagerFqdn`"."
        }
    }
}
Function Get-SddcManagerAccessTokenExpiry {

    <#
        .SYNOPSIS
        Calculates and returns the time-to-live (TTL) in minutes for the current SDDC Manager access token.

        .DESCRIPTION
        The Get-SddcManagerAccessTokenExpiry function decodes and analyzes the current SDDC Manager
        access token to determine how much time remains before it expires. This information is
        crucial for:

        - Proactive token refresh before expiration.
        - Session management and connection health monitoring.
        - Avoiding authentication failures during long-running operations.
        - Determining when reconnection is necessary.

        The function performs JWT (JSON Web Token) decoding to extract the expiration claim,
        converts it to local time, and calculates the remaining time in minutes.

        The process includes:
        1. Extracting the access token from the active connection.
        2. Base64 decoding the JWT payload.
        3. JSON parsing to extract expiration timestamp.
        4. Time zone conversion and TTL calculation.

        .OUTPUTS
        System.Double
        Returns the time-to-live in minutes as a double-precision number.
        Returns $null if token decoding fails.
        Returns $false if no active token exists.

        .EXAMPLE
        $timeRemaining = Get-SddcManagerAccessTokenExpiry
        if ($timeRemaining -lt 30) {
            Connect-SddcManager -reconnect
        }

        Checks token expiry and reconnects if less than 30 minutes remain.

        .EXAMPLE
        $tokenTtl = Get-SddcManagerAccessTokenExpiry
        Write-Host "Token expires in $([math]::Round($tokenTtl, 2)) minutes"

        Displays the remaining token lifetime to the user..

        .NOTES
        - Requires an active SDDC Manager connection.
        - Handles JWT Base64 padding issues automatically.
        - Converts UTC expiration time to local time zone.
        - Returns $false if no token is available.
        - Includes comprehensive error handling for token parsing failures.
    #>

    # This ensures all actions are properly logged.
    New-LogFile

    # Extract the access token from the current SDDC Manager connection.
    # The token is stored in the SessionSecret property of the connection object.
    $accessToken = $Global:defaultSddcManagerConnections.sessionSecret

    # Return False immediately if no token is available (no active connection).
    if (-not $accessToken) {
        return $false
    }

    # Prepare JWT token for Base64 decoding.
    # JWT tokens use URL-safe Base64 encoding and may need padding adjustment.
    foreach ($field in 0..1) {
        # Split JWT by periods and process the payload section (field 1 contains expiration info).
        $sanitizedAccessToken = $accessToken.Split('.')[$field].Replace('-', '+').Replace('_', '/')

        # Add Base64 padding if necessary (Base64 strings must be multiples of 4 characters).
        switch ($sanitizedAccessToken.Length % 4) {
            0 { break }                        # Already properly padded.
            2 { $sanitizedAccessToken += '==' } # Add two padding characters.
            3 { $sanitizedAccessToken += '=' }  # Add one padding character.
        }
    }

    # Decode the JWT token payload and parse as JSON.
    try {
        # Convert Base64 to bytes, then to UTF8 string, then parse as JSON.
        $decodedAccessToken = [System.Text.Encoding]::UTF8.GetString([convert]::FromBase64String($sanitizedAccessToken)) | ConvertFrom-Json -ErrorAction Stop
    } catch [System.FormatException] {
        # Base64 decoding failed - token format issue.
        Write-LogMessage -type ERROR -message "Invalid Base64 format in access token."
        return $null
    } catch [System.ArgumentException] {
        # JSON parsing failed - token structure issue.
        Write-LogMessage -type ERROR -message "Invalid JSON format in decoded access token."
        return $null
    } catch {
        # Any other decoding errors.
        Write-LogMessage -type ERROR -message "Failed to decode access token: $($_.Exception.Message)"
        return $null
    }

    # Convert JWT expiration timestamp to local time and calculate TTL.
    # JWT exp claim is in Unix timestamp format (seconds since January 1, 1970 UTC)

    # Create Unix epoch reference time (January 1, 1970 00:00:00 UTC).
    $originalTime = (Get-Date -Year 1970 -Month 1 -Day 1 -hour 0 -Minute 0 -Second 0 -Millisecond 0)

    # Get current time zone information for conversion.
    $timeZone = Get-TimeZone

    # Convert Unix timestamp to UTC DateTime.
    $utcTime = $originalTime.AddSeconds($decodedAccessToken.Exp)

    # Calculate local time zone offset in minutes.
    $offsetTime = $timeZone.GetUtcOffset($(Get-Date)).TotalMinutes

    # Convert UTC time to local time.
    $localTime = $utcTime.AddMinutes($offsetTime)

    # Calculate time remaining until expiration.
    $timeToExpiry = ($localTime - (Get-Date))

    # Return time-to-live in minutes as a double.
    return $timeToExpiry.TotalMinutes
}
Function Test-SddcManagerConnection {

    <#
        .SYNOPSIS
        Verifies SDDC Manager connection health and automatically handles token refresh or reconnection.

        .DESCRIPTION
        The Test-SddcManagerConnection function provides comprehensive connection health monitoring
        and automatic remediation for SDDC Manager sessions. It performs:.

        - Token expiration checking with configurable minimum TTL.
        - Automatic token refresh when approaching expiration.
        - Connection validation through API calls.
        - Automatic reconnection when tokens are expired or invalid.
        - Graceful handling of various connection failure scenarios.

        The function uses a two-tier approach:
        1. First, check token TTL and refresh if below minimum threshold.
        2. If no token exists, validate connection through API call and reconnect if needed.

        This function should be called before any SDDC Manager API operations to ensure
        a valid, authenticated session is available.

        .EXAMPLE
        Test-SddcManagerConnection

        Verifies connection health and automatically handles any required reconnection.

        .EXAMPLE
        # Before performing SDDC Manager operations
        Test-SddcManagerConnection
        $domains = Invoke-VcfGetDomains

        Ensures valid connection before API calls.

        .NOTES
        - Uses 30-minute minimum TTL threshold by default.
        - Automatically calls Connect-SddcManager when reconnection is needed.
        - Handles both token-based and API-based connection validation.
        - Clears error variables to prevent false positives.
        - Should be called before any long-running operations.
    #>

    # Set minimum token TTL threshold (30 minutes).
    # This provides buffer time for long-running operations.
    $minimumTtl = 30

    # Check current token expiration status
    $tokenTtl = Get-SddcManagerAccessTokenExpiry

    # Primary connection validation: Check token TTL
    if ($tokenTtl) {
        # Token exists - check if it's approaching expiration
        if ([double]$tokenTtl -lt [double]$minimumTtl) {
            # Token expires soon - perform reconnection to refresh
            Connect-SddcManager -reconnect
        }
    } else {
        # No token available or token parsing failed.
        # Attempt API call to validate connection status.
        try {
            # Test connection with a simple API call (result not used, just testing connectivity).
            $null = (Invoke-VcfGetDomains -ErrorAction SilentlyContinue -ErrorVariable ErrorMessage).Elements
        } catch [Exception] {
            # Exception during API call - connection likely invalid.
        }

        # Check for specific authentication/connection errors.
        if ($errorMessage -match "JWT signature|JWT expired|HttpClient.Timeout|TOKEN_NOT_FOUND|You are not currently connected") {
            # Initiate full connection workflow.
            Connect-SddcManager
        }
    }
}
Function Get-SddcManagerVersion {

    <#
        .SYNOPSIS
        The function Get-SddcManagerVersion returns a portion of SDDC Manager release.

        .DESCRIPTION
        The first four version components (Major.Minor.Build.Revision) are extracted from
        the SDDC Manager ProductVersion and returned as a System.Version object.

        .EXAMPLE
        $version = Get-SddcManagerVersion
        # Returns [version]"9.0.0.0"

        .EXAMPLE
        if ((Get-SddcManagerVersion) -ge [version]"9.0.0.0") {
            Write-Host "SDDC Manager 9.0 or later"
        }

        .OUTPUTS
        System.Version
        Returns the SDDC Manager version as a System.Version object, or exits the script on failure.
    #>

    Write-LogMessage -type DEBUG -message "Entered Get-SddcManagerVersion function..."

    # Verify connection exists.
    if (-not $Global:defaultSddcManagerConnections) {
        Write-LogMessage -type ERROR -message "Not connected to SDDC Manager. Use -Connect parameter first."
        Exit-WithCode -exitCode $Script:ExitCodes.CONNECTION_ERROR -message "SDDC Manager connection required."
    }

    # Get version from connection.
    $sddcManagerVersion = $Global:defaultSddcManagerConnections.ProductVersion

    if ([string]::IsNullOrEmpty($sddcManagerVersion)) {
        Write-LogMessage -type ERROR -message "Unable to retrieve SDDC Manager version from connection."
        Exit-WithCode -exitCode $Script:ExitCodes.CONNECTION_ERROR -message "SDDC Manager version unavailable."
    }

    Write-LogMessage -type DEBUG -message "Full SDDC Manager version: $sddcManagerVersion"

    # PowerShell [version] type supports 4 components (Major.Minor.Build.Revision).
    # Extract first 4 version segments from SDDC Manager version string.
    if ($sddcManagerVersion -match '^(\d+\.\d+\.\d+\.\d+)') {
        $sanitizedSddcManagerVersion = $Matches[1]
    } else {
        Write-LogMessage -type ERROR -message "Unable to parse version from: $sddcManagerVersion"
        Exit-WithCode -exitCode $Script:ExitCodes.CONFIGURATION_ERROR -message "Invalid SDDC Manager version format."
    }

    # Convert to [version] type and return.
    try {
        $versionObject = [version]$sanitizedSddcManagerVersion
        return $versionObject
    } catch {
        Write-LogMessage -type ERROR -message "Invalid version format: $sanitizedSddcManagerVersion - $_"
        Exit-WithCode -exitCode $Script:ExitCodes.CONFIGURATION_ERROR -message "Cannot convert to System.Version."
    }
}
Function Connect-Vcenter {

    <#
        .SYNOPSIS
        Establishes a secure connection to vCenter or ESX host instances with unified connection management.

        .DESCRIPTION
        The Connect-Vcenter function creates a secure connection to either vCenter or ESX host
        using PSCredential objects for authentication. It provides unified connection management for both
        server types with intelligent duplicate connection detection and comprehensive error handling.

        The function includes advanced connection state management that checks for existing connections
        and provides detailed information about current sessions, including the connected username.
        It uses SecureString parameters to ensure password security and automatically handles
        connection state validation.

        Key features:
        - Unified connection management for both vCenter and ESX hosts
        - Secure credential handling using PSCredential objects
        - Intelligent duplicate connection detection with existing session details
        - Comprehensive error handling and structured logging
        - Graceful handling of existing connections with detailed user information
        - Connection state validation to prevent duplicate connections

        .PARAMETER serverName
        The fully qualified domain name (FQDN) or IP address of the server to connect to.
        This can be either a vCenter or an ESX host, depending on the ServerType parameter.
        This parameter is mandatory and must be a valid, reachable server instance.

        .PARAMETER serverCredential
        A PSCredential object containing the username and password for authentication to the target server.
        This should contain a valid user account with appropriate permissions for the operations being performed.
        For vCenter: Supports both local vCenter accounts and SSO domain accounts (e.g., administrator@vsphere.local).
        For ESX: Typically uses root account or other local ESX user accounts.
        Using PSCredential objects ensures that passwords are handled securely and not exposed in plain text.

        .PARAMETER serverType
        Specifies the type of server being connected to. Valid values are "vCenter" or "ESX".
        This parameter determines the connection context and affects logging messages and error handling.
        - "vCenter": Connects to a vCenter instance for centralized management
        - "ESX": Connects directly to an ESX host for host-specific operations

        .EXAMPLE
        $credential = Get-Credential -message "Enter vCenter credentials"
        Connect-Vcenter -serverName "vcenter.example.com" -serverCredential $credential -serverType "vCenter"

        Connects to a vCenter using credentials obtained from Get-Credential cmdlet.

        .EXAMPLE
        $securePassword = Read-Host "Enter ESX password" -asSecureString
        $credential = New-Object System.Management.Automation.PSCredential("root", $securePassword)
        Connect-Vcenter -serverName "ESX-host.example.com" -serverCredential $credential -serverType "ESX"

        Connects to an ESX host using a PSCredential object created from secure input.

        .EXAMPLE
        Connect-Vcenter -serverName $Script:vCenterName -serverCredential $vCenterCredential -serverType "vCenter"
        Connect-Vcenter -serverName $esxHost -serverCredential $esxCredential -serverType "ESX"

        Example of connecting to both vCenter and ESX host in sequence using variables.

        .NOTES
        - Requires VMware PowerCLI to be installed and imported before execution
        - The function gracefully handles existing connections and provides detailed information about current sessions
        - Existing connections are detected using $Global:DefaultViServers and the function returns without attempting duplicate connections
        - Connection failures are logged with detailed error information and terminate script execution with exit code 1
        - The function integrates with the VCF PowerShell Toolbox logging infrastructure for consistent reporting
        - Both server types use the same underlying VMware PowerCLI Connect-VIServer cmdlet
        - Username information is displayed for existing connections when available from the connection context
        - Connection attempts use SuppressOutputToScreen for initial connection messages to reduce console verbosity
        - Successful connections are confirmed with informational messages for audit trail purposes
        - Function is designed for use in deployment scenarios where reliable server connectivity is critical

    #>
    Param(
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [PSCredential]$serverCredential,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [String]$serverName,
        [Parameter(Mandatory = $true)] [ValidateSet("vCenter", "ESX")] [String]$serverType
    )

    Write-LogMessage -type DEBUG -message "Entered Connect-Vcenter function..."

    # Check if we're already connected to this vCenter to avoid duplicate connections.
    $connectedVcenter = $Global:DefaultViServers | Where-Object {$_.name -eq $serverName -and $_.IsConnected -eq "true"}

    if (-not $connectedVcenter) {
        # Attempt to establish a new connection to the vCenter.  If it fails, exit the script.
        try {
            Write-LogMessage -type DEBUG -message "Attempting to connect to $serverType Server `"$serverName`"..."
            Connect-VIServer -Server $serverName -Credential $serverCredential -ErrorAction Stop | Out-Null
        } catch [System.TimeoutException] {
            Write-LogMessage -type ERROR -message "Cannot connect to $serverType Server `"$serverName`" due to network/timeout issues: $_"
            exit 1
        }
        catch {
            Write-LogMessage -type ERROR -message "Failed to connect to $serverType `"$serverName`" $_."
            exit 1
        }
        Write-LogMessage -type DEBUG -message "Successfully connected to $serverType `"$serverName`"."
    } else {
        # Connection already exists.  Surface the data on what user the connection is using.
        $existingUsername = ($Global:DefaultVIServers | Where-Object {$_.Name -eq $serverName }).User
        if ($existingUsername) {
            Write-LogMessage -type WARNING -message "Already connected to $serverType `"$serverName`" as `"$existingUsername`"."
        } else {
            Write-LogMessage -type WARNING -message "Already connected to $serverType `"$serverName`"."
        }
    }
}
Function Test-VcenterConnection {
    <#
        .SYNOPSIS
        Tests if an active and valid vCenter connection exists with minimal overhead.

        .DESCRIPTION
        This function efficiently validates that:
        1. A PowerCLI session exists to the specified vCenter
        2. The session is marked as connected (IsConnected = $true)
        3. The connection is actually alive (can execute a lightweight API call)

        The function uses a two-phase check:
        - Phase 1: Fast check of $Global:DefaultViServers (cached session state)
        - Phase 2: Lightweight API call (Get-Datacenter -Name '*') to verify connectivity

        This provides minimal overhead while ensuring the connection is truly functional
        before attempting more complex operations that would fail with cryptic errors.

        .PARAMETER serverName
        The hostname or IP address of the vCenter to test connectivity to.
        If not specified, uses $Script:vCenterName.

        .PARAMETER skipConnectivityTest
        When specified, only checks if a session exists without making an API call.
        This is faster but doesn't verify the connection is still alive (useful if you
        just want to check session existence, not actual connectivity).

        .OUTPUTS
        System.Management.Automation.PSCustomObject
        Returns an object with the following properties:
        - IsConnected: Boolean indicating if connection exists and is valid
        - ServerName: The server name that was tested
        - SessionAge: TimeSpan indicating how long the session has been active
        - ErrorMessage: Error message if connection is invalid (null if connected)

        .EXAMPLE
        # Check connection before critical operation (uses $Script:vCenterName by default)
        $connectionTest = Test-VcenterConnection
        if (-not $connectionTest.IsConnected) {
            Write-LogMessage -type ERROR -message "Not connected to vCenter `"$Script:vCenterName`": $($connectionTest.ErrorMessage)"
            exit 1
        }

        .EXAMPLE
        # Fast check without API call
        $sessionExists = Test-VcenterConnection -skipConnectivityTest
        if ($sessionExists.IsConnected) {
            Write-LogMessage -type DEBUG -suppressOutputToFile -message "Session exists for `"$($sessionExists.ServerName)`" (age: $($sessionExists.SessionAge))"
        } else {
            Write-LogMessage -type WARNING -message "No active session found for `"$Script:vCenterName`""
        }

        .EXAMPLE
        # Test specific vCenter
        $result = Test-VcenterConnection -serverName $Script:vCenterName
        if ($result.IsConnected) {
            Write-LogMessage -type INFO -message "Connection to `"$($result.ServerName)`" is valid"
        }

        .NOTES
        Performance Characteristics:
        - Session check only: <1ms (just checks $Global:DefaultViServers)
        - With connectivity test: ~50-100ms (one lightweight API call)
        - Much faster than retrying failed operations

        Error Handling: This is a validation function. Returns structured result object
        with success/failure information. Does not terminate script execution.

        Use Cases:
        - Before long-running operations to fail fast
        - In loops where connection might time out
        - After network-related errors to determine if reconnection needed
        - In finally blocks to check if cleanup is needed
    #>

    Param(
        [Parameter(Mandatory = $false)] [String]$serverName = $Script:vCenterName,
        [Parameter(Mandatory = $false)] [Switch]$skipConnectivityTest
    )

    Write-LogMessage -type DEBUG -suppressOutputToFile -message "Entered Test-VcenterConnection function..."

    # Initialize result object.
    $result = [PSCustomObject]@{
        IsConnected = $false
        ServerName = $serverName
        SessionAge = $null
        ErrorMessage = $null
    }

    # Phase 1: Check if session exists in PowerCLI session cache.
    try {
        $vcServer = $Global:DefaultViServers | Where-Object {
            $_.Name -eq $serverName -and $_.IsConnected -eq $true
        }

        if (-not $vcServer) {
            $result.ErrorMessage = "No active PowerCLI session found for vCenter `"$serverName`""
            Write-LogMessage -type DEBUG -suppressOutputToFile -message $result.ErrorMessage
            return $result
        }

        # Calculate session age
        if ($vcServer.ServiceUri.StartTime) {
            $result.SessionAge = (Get-Date) - $vcServer.ServiceUri.StartTime
        } elseif ($vcServer.ExtensionData.Content.About.ApiVersion) {
            # Session exists but start time not available - estimate as "recent"
            $result.SessionAge = [TimeSpan]::FromMinutes(0)
        }

        Write-LogMessage -type DEBUG -suppressOutputToFile -message "PowerCLI session exists for `"$serverName`" (age: $($result.SessionAge))"

        # If skip connectivity test, return now (session exists)
        if ($skipConnectivityTest) {
            $result.IsConnected = $true
            return $result
        }

        # Phase 2: Verify connection is actually alive with lightweight API call
        # Using Get-Datacenter because it's:
        # - Fast (small response)
        # - Always available (every vCenter has at least one datacenter)
        # - Read-only (no side effects)
        # - Validates authentication and API access
        Write-LogMessage -type DEBUG -suppressOutputToFile -message "Performing connectivity test to `"$serverName`"..."

        $null = Get-Datacenter -Server $serverName -ErrorAction Stop | Select-Object -First 1

        # Connection is valid
        $result.IsConnected = $true
        Write-LogMessage -type DEBUG -suppressOutputToFile -message "Connection to `"$serverName`" is active and valid"
        return $result

    } catch [VMware.VimAutomation.ViCore.Types.V1.ErrorHandling.InvalidLogin] {
        $result.ErrorMessage = "Authentication failed for vCenter `"$serverName`". Session may have expired."
        Write-LogMessage -type WARNING -message $result.ErrorMessage
        return $result
    } catch [VMware.VimAutomation.Sdk.Types.V1.ErrorHandling.VimException.ViServerConnectionException] {
        $result.ErrorMessage = "Connection to vCenter `"$serverName`" was lost. Network issue or vCenter restart."
        Write-LogMessage -type WARNING -message $result.ErrorMessage
        return $result
    } catch {
        $result.ErrorMessage = "Unable to verify connection to vCenter `"$serverName`": $_"
        Write-LogMessage -type WARNING -message $result.ErrorMessage
        return $result
    }
}
Function Disconnect-Vcenter {

    <#
        .SYNOPSIS
        Safely disconnects from vCenter or ESX host instances with support for individual or bulk disconnection.

        .DESCRIPTION
        The Disconnect-Vcenter function provides a safe and reliable way to disconnect from
        vCenter and/or ESX host instances. It includes comprehensive error handling
        to ensure that disconnection failures are properly logged and handled. The function
        supports both individual server disconnection and bulk disconnection from all active
        connections, making it flexible for various cleanup scenarios.

        The function uses forced disconnection with confirmation suppression to ensure
        reliable cleanup in automated scenarios, making it ideal for script cleanup
        operations and error handling routines. After disconnection, it verifies that
        all connections have been properly terminated by checking $Global:DefaultVIServer.

        Key features:
        - Individual or bulk disconnection management for vCenter and ESX hosts
        - Safe disconnection with comprehensive error handling
        - Post-disconnection verification to ensure clean state
        - Forced disconnection to handle active operations gracefully
        - Confirmation suppression for automated execution
        - Integration with VCF PowerShell Toolbox logging infrastructure

        The function is typically called at the end of scripts, in error handling
        scenarios, or when switching between different server connections to ensure
        proper cleanup of VMware PowerCLI connections.

        .PARAMETER allServers
        Optional switch parameter that disconnects from all active vCenter and ESX host connections.
        When specified, the function uses wildcard disconnection (Disconnect-VIServer -Server *)
        to terminate all active PowerCLI sessions. This is useful for cleanup scenarios where
        all connections should be terminated regardless of which servers are connected.
        Cannot be used together with ServerName parameter.

        .PARAMETER serverName
        Optional. The fully qualified domain name (FQDN) or IP address of a specific server to disconnect from.
        This can be either a vCenter or an ESX host, depending on the ServerType parameter.
        This should match the server name used in the original connection.
        Required when AllServers is not specified.

        .PARAMETER serverType
        Optional. Specifies the type of server being disconnected from. Valid values are "vCenter" or "ESX".
        This parameter is used for logging context but is not strictly required for disconnection.
        - "vCenter": Indicates disconnection from a vCenter instance
        - "ESX": Indicates disconnection from an ESX host instance

        .PARAMETER silence
        Optional switch parameter that suppresses console output for disconnection success messages.
        When specified, successful disconnections are logged with SuppressOutputToScreen flag,
        preventing console output while maintaining log file entries. Error messages are still
        displayed regardless of this parameter. This is useful for automated scenarios where
        verbose console output should be minimized while preserving audit trail functionality.

        .EXAMPLE
        Disconnect-Vcenter -allServers

        Disconnects from all active vCenter and ESX host connections with verification.
        This is the recommended approach for script cleanup and error handling.

        .EXAMPLE
        Disconnect-Vcenter -allServers -silence

        Quietly disconnects from all active connections with suppressed console output.
        Useful for automated cleanup scenarios.

        .EXAMPLE
        Disconnect-Vcenter -serverName "vcenter.example.com" -serverType "vCenter"

        Disconnects from a specific vCenter with error handling and logging.

        .EXAMPLE
        Disconnect-Vcenter -serverName $esxHost -serverType "ESX" -silence

        Disconnects from a specific ESX host with suppressed console output for success messages.

        .NOTES
        - Requires VMware PowerCLI to be installed and imported before execution
        - The function uses Force parameter to ensure disconnection even with active operations or tasks
        - Confirmation prompts are suppressed (Confirm:$false) for automated execution in scripts
        - Post-disconnection verification checks $Global:DefaultVIServer to ensure clean state
        - If any connections remain after disconnection attempt, the function exits with code 1
        - The allServers switch is recommended for cleanup scenarios to ensure all connections are terminated
        - Error handling provides detailed logging with ErrorAction:Stop to ensure disconnection failures are caught
        - The function integrates with VCF PowerShell Toolbox logging infrastructure for consistent reporting
        - Proper disconnection prevents resource leaks and ensures clean session management
        - Function is designed for use in cleanup scenarios, error handling routines, and temporary connection management

    #>

    Param(
        [Parameter(Mandatory = $false)] [ValidateNotNullOrEmpty()] [Switch]$allServers,
        [Parameter(Mandatory = $false)] [ValidateNotNullOrEmpty()] [String]$serverName,
        [Parameter(Mandatory = $false)] [ValidateSet("vCenter", "ESX")] [String]$serverType,
        [Parameter(Mandatory = $false)] [ValidateNotNullOrEmpty()] [Switch]$silence
    )
    Write-LogMessage -type DEBUG -message "Entered Disconnect-Vcenter function..."

    # Disconnect from vCenter.  Stop on error.
    try {
        if ($allServers) {
            Disconnect-VIServer -Server * -Force -Confirm:$false -ErrorAction:Stop | Out-Null
        } else {
            Disconnect-VIServer -Server $serverName -Force -Confirm:$false -ErrorAction:Stop | Out-Null
        }
    } catch {
    }
    # Double check that all servers are disconnected.
    if ($null -eq $Global:DefaultVIServer) {
        if ($silence) {
            Write-LogMessage -type DEBUG -message "Successfully disconnected from all vCenter and ESX hosts"
        } else {
            Write-LogMessage -type INFO -message "Successfully disconnected from all vCenter and ESX hosts"
        }
    } else {
        Write-LogMessage -type INFO -message "Failed to disconnect all vCenter and ESX hosts: $Global:DefaultVIServer"
        exit 1
    }
}
Function Test-VCenterVersion {

    <#
        .SYNOPSIS
        Validates that vCenter is running a specified minimum version or later.

        .DESCRIPTION
        The Test-VCenterVersion function checks the version of the connected vCenter
        to ensure it meets a specified minimum version requirement. This validation is critical
        for ensuring that the vCenter supports the features and APIs required for
        deployment operations.

        The function retrieves the vCenter version from the connected vCenter instance
        (identified by $Script:vCenterName) using the PowerCLI API version information. It
        accepts a minimum required version as a parameter in the format "major.minor.patch"
        (e.g., "9.0.0") and performs a semantic version comparison to validate that the
        detected version meets or exceeds the requirement.

        The minimum version string is parsed within the function to extract major, minor, and
        patch components for comparison against the detected vCenter version.

        Key features:
        - Retrieves vCenter version from active connection using $Script:vCenterName
        - Accepts flexible minimum version parameter (major.minor.patch format)
        - Performs semantic version comparison (major.minor.patch)
        - Provides detailed error messages for version mismatches
        - Logs version information for audit trail
        - Returns standardized result object for error handling

        .PARAMETER minimumVersion
        The minimum required version in "major.minor.patch" format (e.g., "9.0.0", "8.0.3").
        This parameter is mandatory and determines the version threshold for validation.
        The version string must contain at least three dot-separated numeric components.

        .EXAMPLE
        $result = Test-VCenterVersion -minimumVersion "9.0.0"
        if (-not $result.Success) {
            Write-Host "Version validation failed: $($result.ErrorMessage)"
            exit 1
        }

        Validates the vCenter version against a minimum requirement of 9.0.0.

        .EXAMPLE
        Test-VCenterVersion -minimumVersion "8.0.3"

        Validates the vCenter version with a minimum requirement of 8.0.3.

        .OUTPUTS
        PSCustomObject
        Returns an object with the following properties:
        - Success: Boolean indicating whether validation passed
        - ErrorMessage: String containing error details if validation failed (null on success)
        - ErrorCode: String containing error code if validation failed (null on success)
        - Version: String containing the detected vCenter version
        - MinimumVersion: String containing the minimum required version

        .NOTES
        - Requires an active connection to vCenter (via Connect-Vcenter)
        - Uses $Script:vCenterName global variable to identify the connected vCenter
        - The function uses $Global:DefaultViServers to access connection information
        - Version comparison follows semantic versioning rules (major.minor.patch)
        - Returns error result object on failure instead of throwing exceptions
        - Integrates with Write-LogMessage for consistent logging
        - Version strings must be in format "major.minor.patch" (e.g., "9.0.0")

        Error Handling: Validation function. Returns structured error object via Write-ErrorAndReturn
        on any validation failure. Caller should check $result.Success and decide whether to exit
        or continue. Typically, main workflow functions call 'exit 1' on version validation failure.

        .LINK
        Connect-Vcenter
        Disconnect-Vcenter
    #>

    Param(
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [String]$minimumVersion
    )

    Write-LogMessage -type DEBUG -message "Entered Test-VCenterVersion function..."

    try {
        # Get the connected vCenter instance using the script-scoped vCenter name
        $vcServer = $Global:DefaultViServers | Where-Object { $_.Name -eq $Script:vCenterName -and $_.IsConnected }

        if (-not $vcServer) {
            return Write-ErrorAndReturn -errorMessage "Not connected to vCenter `"$Script:vCenterName`". Please establish a connection first." -errorCode "ERR_NOT_CONNECTED"
        }

        # Get the vCenter version from the API version property
        $vcVersionString = $vcServer.Version

        if (-not $vcVersionString) {
            return Write-ErrorAndReturn -errorMessage "Unable to retrieve version information from vCenter `"$Script:vCenterName`"." -errorCode "ERR_VERSION_UNAVAILABLE"
        }

        Write-LogMessage -type DEBUG -message "Detected vCenter `"$Script:vCenterName`" version: $vcVersionString"

        # Convert version strings to [version] type for proper semantic version comparison
        try {
            $vcVersion = [version]$vcVersionString
            $minVersion = [version]$minimumVersion
        } catch {
            return Write-ErrorAndReturn -errorMessage "Failed to parse version strings. vCenter version: `"$vcVersionString`", Minimum version: `"$minimumVersion`". Both must be in valid version format (e.g., 9.0.0)." -errorCode "ERR_VERSION_PARSE_FAILED"
        }

        # Compare versions using [version] type comparison (automatically handles major.minor.build.revision)
        if ($vcVersion -lt $minVersion) {
            return Write-ErrorAndReturn -errorMessage "vCenter `"$Script:vCenterName`" version $vcVersionString does not meet minimum required version: $minimumVersion. Please upgrade vCenter." -errorCode "ERR_VERSION_TOO_OLD"
        }

        # Version validation passed
        Write-LogMessage -type INFO -message "vCenter `"$Script:vCenterName`" version $vcVersionString meets minimum required version: $minimumVersion."

        return @{
            Success = $true
            ErrorMessage = $null
            ErrorCode = $null
            Version = $vcVersionString
            MinimumVersion = $minimumVersion
        }

    } catch {
        return Write-ErrorAndReturn -errorMessage "Failed to validate vCenter version for `"$Script:vCenterName`": $_" -errorCode "ERR_VALIDATION_EXCEPTION"
    }
}