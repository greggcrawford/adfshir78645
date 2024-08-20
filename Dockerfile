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

# Re-instantiate ARG instructions
ARG STORAGE_ACCOUNT_NAME
ARG CONTAINER_NAME

# Download SHIR files from Azure Storage using Azure CLI and managed identity
RUN powershell.exe -Command \
  $ErrorActionPreference = 'Stop'; \
  az login --identity

RUN powershell.exe -Command \
  $files = @("build.ps1", "setup.ps1", "health-check.ps1", "IntegrationRuntime_5.44.8984.1.msi"); \
  foreach ($file in $files) { \
    az storage blob download --account-name "$env:STORAGE_ACCOUNT_NAME" --container-name "$env:CONTAINER_NAME" --name $file --file "C:\SHIR\$file" --auth-mode login \
  }

# Run the build script
RUN powershell.exe -Command "C:/SHIR/build.ps1"

# Set the entry point to the setup script
ENTRYPOINT ["powershell.exe", "C:/SHIR/setup.ps1"]

# Set environment variable for SHIR
ENV SHIR_WINDOWS_CONTAINER_ENV True

# Health check
HEALTHCHECK --start-period=120s CMD ["powershell.exe", "C:/SHIR/health-check.ps1"]
