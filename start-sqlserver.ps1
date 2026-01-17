# SQL Server Startup Script for Docker Container
$ErrorActionPreference = 'Stop'

Write-Host "Starting SQL Server..."

# Start SQL Server service
Start-Service -Name 'MSSQLSERVER'

# Start SQL Server Agent service
Start-Service -Name 'SQLSERVERAGENT' -ErrorAction SilentlyContinue

Write-Host "SQL Server started successfully."
Write-Host "SQL Server is ready to accept connections on port 1433."

# Keep the container running by tailing the SQL Server error log
$errorLogPath = "C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Log\ERRORLOG"

# Wait for the error log to be created
while (-not (Test-Path $errorLogPath)) {
    Start-Sleep -Seconds 2
}

# Monitor the error log to keep container alive and show logs
Get-Content -Path $errorLogPath -Wait -Tail 100
