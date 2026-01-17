# SQL Server 2022 Developer on Windows Server Container

This project creates a Docker image running SQL Server 2022 Developer Edition on Windows Server Core 2022, with an unattended installation configured via Docker Compose.

## Project Structure

| File | Description |
|------|-------------|
| `Dockerfile` | Windows Server Core 2022 image with SQL Server 2022 unattended install |
| `ConfigurationFile.ini` | SQL Server unattended installation configuration |
| `start-sqlserver.ps1` | Startup script to run SQL Server as container entrypoint |
| `docker-compose.yml` | Compose file with persistent volumes |

## Prerequisites

### Windows Containers Mode (Required)

This project uses Windows containers, which require Docker Desktop to be running in **Windows containers mode**. By default, Docker Desktop runs in Linux containers mode.

#### How to Enable Windows Containers

1. **Enable Required Windows Features** (run PowerShell as Administrator):
   ```powershell
   Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
   Enable-WindowsOptionalFeature -Online -FeatureName Containers -All
   ```

2. **Restart your computer** after enabling the features.

3. **Switch Docker to Windows Containers**:
   - Right-click the Docker Desktop icon in your system tray
   - Select **"Switch to Windows containers..."**
   - Confirm when prompted

   Alternatively, run:
   ```powershell
   & "C:\Program Files\Docker\Docker\DockerCli.exe" -SwitchDaemon
   ```

4. **Verify Windows containers are active**:
   ```powershell
   docker version
   ```
   The Server section should show `OS/Arch: windows/amd64`.

#### Troubleshooting: "Windows containers have been disabled"

If you see this message when trying to switch to Windows containers:

1. **Docker Desktop may need reinstallation** with Windows containers support:
   - Uninstall Docker Desktop
   - Download the latest installer from [Docker Desktop](https://www.docker.com/products/docker-desktop/)
   - During installation, ensure **"Enable Windows containers"** is checked

2. **Windows Edition**: Windows containers require Windows 10/11 Pro, Enterprise, or Education. Windows Home edition does not support Windows containers.

3. **Virtualization**: Ensure virtualization is enabled in your BIOS/UEFI settings.

## Setup

### Create the Environment File

Before building or running the container, you must create a `.env` file in the project root with your SA password:

```powershell
# Create .env file
@"
SA_PASSWORD=YourStrong!Passw0rd
"@ | Out-File -FilePath .env -Encoding UTF8
```

Or manually create a `.env` file with the following content:

```
SA_PASSWORD=YourStrong!Passw0rd
```

**Password Requirements**:
- At least 8 characters
- Contains uppercase, lowercase, numbers, and symbols

> **Note**: The `.env` file is excluded from git via `.gitignore` to prevent committing sensitive data.

## Usage

### Build the Image

```powershell
docker-compose build
```

> **Note**: The initial build will take a significant amount of time as it downloads and installs SQL Server 2022.

### Start the Container

```powershell
docker-compose up -d
```

### View Logs

```powershell
docker-compose logs -f sqlserver
```

### Stop the Container

```powershell
docker-compose down
```

## Connection Details

| Property | Value |
|----------|-------|
| Server | `localhost,1433` |
| Username | `sa` |
| Password | `YourStrong!Passw0rd` |

### Example Connection String

```
Server=localhost,1433;Database=master;User Id=sa;Password=YourStrong!Passw0rd;TrustServerCertificate=True;
```

## Data Persistence

SQL Server data is persisted using Docker named volumes:

| Volume | Container Path | Purpose |
|--------|----------------|---------|
| `sqlserver-data` | `C:\SQLServerData` | Database files |
| `sqlserver-logs` | `C:\SQLServerLogs` | Transaction logs |
| `sqlserver-backup` | `C:\SQLServerBackup` | Backup files |

Data survives container restarts and removals. To completely reset, remove the volumes:

```powershell
docker-compose down -v
```

## Configuration

### Changing the SA Password

Update the `SA_PASSWORD` value in your `.env` file. The password is used both during image build and at container runtime.

**Password Requirements**:
- At least 8 characters
- Contains uppercase, lowercase, numbers, and symbols

> **Important**: If you change the password, you must rebuild the image with `docker-compose build` for the change to take effect.

### SQL Server Configuration

The `ConfigurationFile.ini` contains the unattended installation settings. Key configurations:

- **Instance Name**: `MSSQLSERVER` (default instance)
- **Features**: Database Engine only (SQLENGINE)
- **Security Mode**: Mixed (SQL + Windows authentication)
- **TCP Enabled**: Yes (port 1433)

