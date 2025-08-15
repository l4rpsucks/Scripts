# Ask for output directory
$outputDir = Read-Host "Enter the directory path to save the log file"
if (-not (Test-Path $outputDir)) {
    Write-Host "Directory does not exist. Creating it..."
    New-Item -Path $outputDir -ItemType Directory | Out-Null
}

$outputFile = Join-Path $outputDir "bat_executions.txt"

Write-Host "Scanning Program Compatibility Assistant logs for .bat executions..."

# Regex pattern for .bat paths
$pattern = '([A-Z]:\\[^\s]+\.bat)'

# Get all PCA events with .bat in message
$events = Get-WinEvent -LogName Application |
    Where-Object { $_.ProviderName -like "Program Compatibility Assistant*" -and $_.Message -match "\.bat" }

# Extract and save just the .bat paths
$foundPaths = @()
foreach ($event in $events) {
    $matches = [regex]::Matches($event.Message, $pattern, 'IgnoreCase')
    foreach ($match in $matches) {
        $foundPaths += $match.Value
    }
}

# Remove duplicates and save
$foundPaths | Sort-Object -Unique | Out-File -FilePath $outputFile -Encoding UTF8

Write-Host "Done! Found $($foundPaths.Count) .bat executions. Saved to: $outputFile"
