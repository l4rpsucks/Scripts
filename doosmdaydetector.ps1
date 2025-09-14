# Define the URL of the JAR file
$jarUrl = "https://doomsdayclient.com/loader/v5ab4f8018d.jar"

# Download the JAR file into a byte array
$jarBytes = Invoke-WebRequest -Uri $jarUrl -UseBasicParsing | Select-Object -ExpandProperty Content

# Define the path to the Java executable
$javaPath = "C:\Program Files\Java\jre1.8.0_301\bin\java.exe"

# Create a temporary file to hold the JAR content
$tempFile = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllBytes($tempFile, $jarBytes)

# Execute the JAR file using the Java executable
Start-Process -FilePath $javaPath -ArgumentList "-jar", $tempFile -NoNewWindow -Wait

# Clean up the temporary file
Remove-Item -Path $tempFile
