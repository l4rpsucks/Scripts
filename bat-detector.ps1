# Ask user for log directory
$logDir = Read-Host "Enter the directory path to save the log file"
if (-not (Test-Path $logDir)) {
    Write-Host "Directory does not exist. Creating it..."
    New-Item -Path $logDir -ItemType Directory | Out-Null
}

# Set log file path
$logFile = Join-Path $logDir "bat_execution_log.csv"

# If log file doesn't exist, create it with headers
if (-not (Test-Path $logFile)) {
    "Timestamp,FilePath,ProcessID" | Out-File -FilePath $logFile
}

Write-Host "Monitoring for .bat file executions. Press Ctrl+C to stop."

# Event filter for .bat executions
$query = @"
SELECT * FROM Win32_ProcessStartTrace
WHERE ProcessName LIKE '%.bat'
"@

Register-WmiEvent -Query $query -SourceIdentifier "BatFileExecution" -Action {
    $time = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $path = $Event.SourceEventArgs.NewEvent.ExecutablePath
    $pid = $Event.SourceEventArgs.NewEvent.ProcessID

    # Append to CSV
    "$time,$path,$pid" | Out-File -FilePath $using:logFile -Append
    Write-Host "Detected .bat execution: $path (PID: $pid)"
}

# Keep script running
while ($true) {
    Start-Sleep 1
}
