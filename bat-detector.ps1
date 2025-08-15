# Ask user for output directory
$outputDir = Read-Host "Enter the directory path to save the log file"
if (-not (Test-Path $outputDir)) {
    Write-Host "Directory does not exist. Creating it..."
    New-Item -Path $outputDir -ItemType Directory | Out-Null
}

$outputFile = Join-Path $outputDir "bat_executions.txt"

Write-Host "Scanning Program Compatibility Assistant logs for all .bat executions..."

# Get all PCA events from Application log
$events = Get-WinEvent -LogName Application |
    Where-Object { $_.ProviderName -like "Program Compatibility Assistant*" -and $_.Message -match "\.bat" }

# Write results
if ($events.Count -gt 0) {
    foreach ($event in $events) {
        $time = $event.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
        $message = $event.Message -replace "`r`n", " "
        Add-Content -Path $outputFile -Value "[$time] $message"
    }
    Write-Host "Done! Found $($events.Count) .bat executions. Log saved to: $outputFile"
} else {
    Write-Host "No .bat executions found in PCA logs."
}
