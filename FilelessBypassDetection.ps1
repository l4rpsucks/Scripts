<#
.SYNOPSIS
  Checks for PowerShell Event ID 600 in the Event Viewer, extracts potentially fileless bypass commands, and saves them to a CSV file.
.DESCRIPTION
  This script queries the Windows Event Log for PowerShell events with ID 600, which logs the start of a PowerShell engine instance.
  It extracts the command (if available) and the date/time of execution, then saves the results to a CSV file.
  The user can choose to save in the current directory or enter a custom directory.
#>

# Prompt user for save location
$choice = Read-Host "Save CSV to current directory? (Y/N)"
if ($choice -match "^[Yy]") {
    $OutputDirectory = Get-Location
} else {
    $OutputDirectory = Read-Host "Enter full path to save the CSV file"
    if (-not (Test-Path $OutputDirectory)) {
        Write-Host "Directory does not exist. Creating: $OutputDirectory"
        New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
    }
}

$CsvFile = Join-Path $OutputDirectory "FilelessBypassDetection.csv"

# Query Event Log for PowerShell Event ID 600
$events = Get-WinEvent -FilterHashtable @{
    LogName='Windows PowerShell'
    Id=600
} | Select-Object -Property TimeCreated, Message

# Parse events for command lines (fileless bypasses often show suspicious command usage)
$results = @()
foreach ($event in $events) {
    $command = ""
    # Event 600's Message field may contain 'CommandLine = ...'
    if ($event.Message -match "CommandLine = (.+)") {
        $command = $matches[1].Trim()
    }
    # Only record events with non-empty command lines
    if ($command) {
        $results += [PSCustomObject]@{
            Date    = $event.TimeCreated
            Command = $command
        }
    }
}

# Export to CSV
$results | Export-Csv -Path $CsvFile -NoTypeInformation -Force

Write-Host "`nSaved results to $CsvFile"
