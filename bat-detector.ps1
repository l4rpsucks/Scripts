# ====== USER CONFIG ======
# Set the full path where you want the CSV saved, e.g. "C:\Logs\PowerShell_Events.csv"
$outputFile = "C:\Your\Path\Here\PowerShell_Events.csv"
# ========================

# Define the Event Log and IDs to fetch
$logName = "Microsoft-Windows-PowerShell/Operational"
$eventIDs = @(400, 403, 800, 4103, 4104)

# Fetch the events
$events = Get-WinEvent -LogName $logName | Where-Object { $eventIDs -contains $_.Id }

# Create a custom object for CSV export
$eventsForCsv = $events | ForEach-Object {
    [PSCustomObject]@{
        TimeCreated = $_.TimeCreated
        Id          = $_.Id
        Level       = $_.LevelDisplayName
        Message     = $_.Message -replace "`r`n"," "  # Single-line message
        User        = if ($_.Properties.Count -gt 0) { $_.Properties[0].Value } else { "" }
    }
}

# Ensure the folder exists
$folder = Split-Path $outputFile
if (!(Test-Path $folder)) { New-Item -ItemType Directory -Path $folder -Force }

# Export to CSV
$eventsForCsv | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8

Write-Host "Events exported to $outputFile"
