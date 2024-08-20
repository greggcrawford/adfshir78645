# Use the Windows Server 2022 base image
FROM mcr.microsoft.com/windows/servercore:ltsc2022

# Install Azure CLI
RUN powershell.exe -Command \
  $ErrorActionPreference = 'Stop'; \
  Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile AzureCLI.msi; \
  Start-Process msiexec.exe -ArgumentList '/I AzureCLI.msi /quiet' -NoNewWindow -Wait; \
  Remove-Item -Force AzureCLI.msi

# ARG to determine if JDK should be installed
ARG INSTALL_JDK=false

# Echo the build arguments to verify they are passed correctly
ARG STORAGE_ACCOUNT_NAME
ARG CONTAINER_NAME
RUN powershell.exe -Command \
  Write-Host "STORAGE_ACCOUNT_NAME: $env:STORAGE_ACCOUNT_NAME"; \
  Write-Host "CONTAINER_NAME: $env:CONTAINER_NAME"

# Download and install Microsoft's JDK 11 LTS if required
RUN powershell.exe -Command \
  if ($env:INSTALL_JDK -eq 'true') { \
    Invoke-WebRequest -Uri "https://aka.ms/download-jdk/microsoft-jdk-11.0.12.7.1-windows-x64.zip" -OutFile "C:\jdk.zip"; \
    Expand-Archive -Path "C:\jdk.zip" -DestinationPath "C:\jdk" \
  }

# Define variables
$storageAccountName = "acrtest8906795"
$containerName = "acrtest"
$files = @("build.ps1", "setup.ps1", "health-check.ps1", "IntegrationRuntime_5.44.8984.1.msi")

# Download files using Invoke-WebRequest
foreach ($file in $files) {
    $url = "https://$storageAccountName.blob.core.windows.net/$containerName/$file"
    $destinationPath = "C:\SHIR\$file"
    Invoke-WebRequest -Uri $url -OutFile $destinationPath
    Write-Output "Downloaded $file to $destinationPath"
}

# Run the build script
RUN powershell.exe -Command "C:/SHIR/build.ps1"

# Set the entry point to the setup script
ENTRYPOINT ["powershell.exe", "C:/SHIR/setup.ps1"]

# Set environment variable for SHIR
ENV SHIR_WINDOWS_CONTAINER_ENV True

# Health check
HEALTHCHECK --start-period=120s CMD ["powershell.exe", "C:/SHIR/health-check.ps1"]
