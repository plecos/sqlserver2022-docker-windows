# Windows Server 2022 with SQL Server 2022 Developer Edition
# escape=\

FROM mcr.microsoft.com/windows/servercore:ltsc2022

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Build argument for SA password (passed from docker-compose.yml)
ARG SA_PASSWORD

# Set environment variables
ENV SA_PASSWORD=${SA_PASSWORD} \
    ACCEPT_EULA="Y" \
    MSSQL_PID="Developer"

# Create directories
RUN New-Item -ItemType Directory -Path C:\SQLServer2022 -Force; \
    New-Item -ItemType Directory -Path C:\SQLServerData -Force; \
    New-Item -ItemType Directory -Path C:\SQLServerLogs -Force; \
    New-Item -ItemType Directory -Path C:\SQLServerBackup -Force

# Copy build context to temp location for optional media check
COPY . C:/BuildContext/

# Check for local install media and download if not present
RUN $localMedia = Get-ChildItem -Path 'C:\BuildContext\SQLServer2022Media' -Filter '*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1; \
    if ($localMedia) { \
        Write-Host "SQL Server installation media found locally: $($localMedia.Name)"; \
        Copy-Item -Path $localMedia.FullName -Destination 'C:\SQLServer2022\Media\' -Force \
    } else { \
        Write-Host 'Downloading SQL Server 2022...'; \
        Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/p/?linkid=2215158&clcid=0x409&culture=en-us&country=us' \
            -OutFile 'C:\SQLServer2022\SQL2022-SSEI-Dev.exe'; \
        Write-Host 'Downloading SQL Server installation media...'; \
        Start-Process -FilePath 'C:\SQLServer2022\SQL2022-SSEI-Dev.exe' \
            -ArgumentList '/Action=Download', '/MediaPath=C:\SQLServer2022\Media', '/MediaType=CAB', '/Quiet' \
            -Wait -NoNewWindow \
    }; \
    Remove-Item -Path 'C:\BuildContext' -Recurse -Force -ErrorAction SilentlyContinue

# Extract the downloaded CAB package
RUN $setupExists = Test-Path 'C:\SQLServer2022\Setup\setup.exe'; \
    if ($setupExists) { \
        Write-Host 'SQL Server setup files already extracted, skipping extraction.' \
    } else { \
        Write-Host 'Extracting SQL Server installation files...'; \
        $cabExe = Get-ChildItem -Path 'C:\SQLServer2022\Media' -Filter '*.exe' | Select-Object -First 1; \
        Write-Host "Found: $($cabExe.FullName)"; \
        Start-Process -FilePath $cabExe.FullName -ArgumentList '/q', "/x:C:\SQLServer2022\Setup" -Wait -NoNewWindow; \
        Write-Host 'Extraction complete.' \
    }; \
    Write-Host 'Setup files:'; \
    Get-ChildItem -Path 'C:\SQLServer2022\Setup' -Recurse | ForEach-Object { Write-Host $_.FullName }

# Copy configuration file
COPY ConfigurationFile.ini C:/SQLServer2022/ConfigurationFile.ini

# Install SQL Server 2022 unattended
RUN Write-Host 'Installing SQL Server 2022 Developer Edition...'; \
    $setupExe = Get-ChildItem -Path 'C:\SQLServer2022\Setup' -Filter 'setup.exe' -Recurse | Select-Object -First 1; \
    if ($setupExe) { \
        Write-Host "Running setup from: $($setupExe.FullName)"; \
        Start-Process -FilePath $setupExe.FullName \
            -ArgumentList '/ConfigurationFile=C:\SQLServer2022\ConfigurationFile.ini', \
                          "/SAPWD=$env:SA_PASSWORD", \
                          '/IACCEPTSQLSERVERLICENSETERMS' \
            -Wait -NoNewWindow; \
        Write-Host 'SQL Server installation completed.' \
    } else { \
        Write-Error 'Setup.exe not found!' \
    }

# Clean up installation files to reduce image size (keep Media for future builds)
RUN Remove-Item -Path 'C:\SQLServer2022\SQL2022-SSEI-Dev.exe' -Force -ErrorAction SilentlyContinue; \
    Remove-Item -Path 'C:\SQLServer2022\Setup' -Recurse -Force -ErrorAction SilentlyContinue

# Copy startup script
COPY start-sqlserver.ps1 C:/start-sqlserver.ps1

# Expose SQL Server port
EXPOSE 1433

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD powershell -Command "try { $conn = New-Object System.Data.SqlClient.SqlConnection('Server=localhost;Database=master;Integrated Security=False;User Id=sa;Password=' + $env:SA_PASSWORD); $conn.Open(); $conn.Close(); exit 0 } catch { exit 1 }"

# Start SQL Server
CMD ["powershell", "-File", "C:\\start-sqlserver.ps1"]
