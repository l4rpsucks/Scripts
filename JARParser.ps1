Clear-Host

$pecmdUrl = "https://github.com/NoDiff-del/JARs/releases/download/Jar/PECmd.exe"
$xxstringsUrl = "https://github.com/NoDiff-del/JARs/releases/download/Jar/xxstrings64.exe"

$pecmdPath = "$env:TEMP\PECmd.exe"
$xxstringsPath = "$env:TEMP\xxstrings64.exe"

Invoke-WebRequest -Uri $pecmdUrl -OutFile $pecmdPath
Invoke-WebRequest -Uri $xxstringsUrl -OutFile $xxstringsPath

$logonTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime

$prefetchFolder = "C:\Windows\Prefetch"
$files = Get-ChildItem -Path $prefetchFolder -Filter *.pf
$filteredFiles = $files | Where-Object { 
    ($_.Name -match "java|javaw") -and ($_.LastWriteTime -gt $logonTime)
}

if ($filteredFiles.Count -gt 0) {
    Write-Host "PF files found after logon time.." -ForegroundColor Gray
    $filteredFiles | ForEach-Object { 
        Write-Host " "
        Write-Host $_.FullName -ForegroundColor DarkCyan
        $prefetchFilePath = $_.FullName
        $pecmdOutput = & $pecmdPath -f $prefetchFilePath
        $filteredImports = $pecmdOutput

        if ($filteredImports.Count -gt 0) {
            Write-Host "Imports found:" -ForegroundColor DarkYellow
            $filteredImports | ForEach-Object {
                $line = $_
                if ($line -match '\\VOLUME{(.+?)}') {
                    $line = $line -replace '\\VOLUME{(.+?)}', 'C:'
                }
                $line = $line -replace '^\d+: ', ''

                try {
                    if ((Get-Content $line -First 1 -ErrorAction SilentlyContinue) -match 'PK\x03\x04') {
                        if ($line -notmatch "\.jar$") {
                            Write-Host "File .jar modified extension: $line " -ForegroundColor DarkRed
                        } else {
                            Write-Host "Valid .jar file: $line" -ForegroundColor DarkGreen
                        }
                    }
                } catch {
                    if ($line -match "\.jar$") {
                        Write-Host "File .jar deleted maybe: $line" -ForegroundColor DarkYellow
                    }
                }

                if ($line -match "\.jar$" -and !(Test-Path $line)) {
                    Write-Host "File .jar deleted maybe: $line" -ForegroundColor DarkYellow
                }
            }
        } else {
            Write-Host "No imports found for the file $($_.Name)." -ForegroundColor Red
        }
    }
} else {
    Write-Host "No PF files containing 'java' or 'javaw' and modified after logon time were found." -ForegroundColor Red
}

Write-Output " "
Write-Host "Searching for DcomLaunch PID..." -ForegroundColor Gray

$pidDcomLaunch = (Get-CimInstance -ClassName Win32_Service | Where-Object { $_.Name -eq 'DcomLaunch' }).ProcessId

$xxstringsOutput = & $xxstringsPath -p $pidDcomLaunch -raw | findstr /C:"-jar"

if ($xxstringsOutput) {
    Write-Host "Strings found in DcomLaunch process memory containing '-jar':" -ForegroundColor DarkYellow

    $xxstringsOutput | ForEach-Object {
        Write-Host $_ -ForegroundColor Gray

        # Try to extract a .jar path after the -jar argument
        if ($_ -match '-jar\s+"?([^"\s]+\.jar)"?') {
            $jarPath = $Matches[1]

            # Replace \VOLUME{} if present
            if ($jarPath -match '\\VOLUME{[^}]+}') {
                $jarPath = $jarPath -replace '\\VOLUME{[^}]+}', 'C:'
            }

            Write-Host "`nProcessing JAR file: $jarPath" -ForegroundColor Cyan

            try {
                $firstByte = Get-Content $jarPath -Encoding Byte -TotalCount 4 -ErrorAction Stop
                if ($firstByte[0] -eq 0x50 -and $firstByte[1] -eq 0x4B -and $firstByte[2] -eq 0x03 -and $firstByte[3] -eq 0x04) {
                    Write-Host "Valid .jar file in memory string: $jarPath" -ForegroundColor DarkGreen
                } else {
                    Write-Host "Invalid .jar file (wrong magic): $jarPath" -ForegroundColor DarkRed
                }
            } catch {
                Write-Host "File not found or inaccessible: $jarPath" -ForegroundColor DarkYellow
            }
        } else {
            Write-Host "Could not extract .jar path from string: $_" -ForegroundColor Red
        }
    }
} else {
    Write-Host "No strings containing '-jar' were found in DcomLaunch process memory." -ForegroundColor Red
}

