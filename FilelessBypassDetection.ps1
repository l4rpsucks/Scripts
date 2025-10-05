# FilelessScriptDetector.ps1
# Dumps event logs for command-line and PowerShell history.
# Flags suspicious commands and saves all results to FilelessDetection.txt.

$OutFile = ".\FilelessDetection.txt"

# Define suspicious patterns (case-insensitive)
$flagPatterns = @(
    'iwr',                            # Short for Invoke-WebRequest
    'invoke-web',                     # Invoke-WebRequest and similar
    'type ',                          # 'type' as a fileless technique
    'echo ',                          # 'echo' as a bypass technique
    'mklink /h',                      # Hardlink creation
    'powershell',                     # Direct PowerShell invocation
    'curl',                           # curl for remote download
    'certutil',                       # certutil for file transfer
    'Invoke-Expression',
    'Invoke-Command',
    'New-Object Net\.WebClient',      # WebClient creation
    'DownloadData',                   # DownloadData usage
    'Dispose\(\)',                    # Cleanup of the WebClient object
    'github\.com\/EuphorianXD\/Prestige-injector',  # Specific URL pattern
    'GetTempFileName',                # Creating temp files
    # Obfuscation patterns
    'FromBase64String',               # Base64 encoded payloads
    '-EncodedCommand',                # PowerShell encoded command
    '\[char\]\d+',                    # [char] casting
    '\$\w+\s*\+\s*\$\w+',             # Variable concatenation like $a+$b
    '\$\w+\s*&\s*\$\w+',              # Variable & concatenation
    '([A-Fa-f0-9]{2,}\\x)+',          # Hex escapes
    '`{2,}',                          # Excessive backticks
    '\^{2,}',                         # Excessive carets
    '\$\w+\s*=\s*\$\w+',              # Variable assignment from another variable
    '([Uu][0-9A-Fa-f]{4,})',          # Unicode escapes
    '[System\.Text\.Encoding]',       # Encoding usage
    '[System\.Convert]',              # Conversion usage
    '\$\w+\s*=\s*"[^"]*"\s*\+\s*"[^"]*"' # String concatenation
)

# Get command-line events (EID 4688: process creation, EID 4104: PowerShell script block logging)
$cmdEvents = Get-WinEvent -FilterHashtable @{ 
    LogName='Security'
    Id=4688
} -ErrorAction SilentlyContinue

$psEvents = Get-WinEvent -FilterHashtable @{ 
    LogName='Microsoft-Windows-PowerShell/Operational'
    Id=4104
} -ErrorAction SilentlyContinue

$results = @()

# Parse command-line events
foreach ($event in $cmdEvents) {
    $cmdLine = $event.Properties[8].Value
    if ($null -ne $cmdLine -and $cmdLine -ne "") {
        $flagged = $false
        foreach ($pattern in $flagPatterns) {
            if ($cmdLine -match "(?i)$pattern") {
                $flagged = $true
                break
            }
        }
        if ($flagged) {
            $results += "[FLAGGED] $cmdLine"
        } else {
            $results += "$cmdLine"
        }
    }
}

# Parse PowerShell events
foreach ($event in $psEvents) {
    $psCmd = $event.Properties[2].Value
    if ($null -ne $psCmd -and $psCmd -ne "") {
        $flagged = $false
        foreach ($pattern in $flagPatterns) {
            if ($psCmd -match "(?i)$pattern") {
                $flagged = $true
                break
            }
        }
        if ($flagged) {
            $results += "[FLAGGED] $psCmd"
        } else {
            $results += "$psCmd"
        }
    }
}

# Save to file
$results | Set-Content -Path $OutFile

Write-Host "Detection complete. Results saved in $OutFile."
