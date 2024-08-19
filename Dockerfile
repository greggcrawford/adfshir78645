# Use the Windows Server 2022 base image
FROM mcr.microsoft.com/windows/servercore:ltsc2022

# Install Azure CLI
RUN powershell -Command `
    Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile AzureCLI.msi; `
    Start-Process msiexec.exe -ArgumentList '/I AzureCLI.msi /quiet' -NoNewWindow -Wait; `
    Remove-Item -Force AzureCLI.msi

# ARG to determine if JDK should be installed
ARG INSTALL_JDK=false

# Download and install Microsoft's JDK 11 LTS if required
RUN if %INSTALL_JDK%==true powershell -Command `
    Invoke-WebRequest -Uri "https://aka.ms/download-jdk/microsoft-jdk-11.0.12.7.1-windows-x64.zip" -OutFile "C:\jdk.zip"; `
    Expand-Archive -Path "C:\jdk.zip" -DestinationPath "C:\jdk"

# Download SHIR files from Azure Storage using managed identity
ARG STORAGE_ACCOUNT_NAME
ARG CONTAINER_NAME
RUN powershell -Command `
    $ErrorActionPreference = 'Stop'; `
    $env:AZURE_CLIENT_ID = (Invoke-RestMethod -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2019-08-01&resource=https://management.azure.com/' -Headers @{Metadata='true'}).client_id; `
    az login --identity; `
    $token = (az account get-access-token --resource https://storage.azure.com/ --query accessToken --output tsv); `
    $headers = @{Authorization = "Bearer $token"}; `
    $files = @("build.ps1", "setup.ps1", "health-check.ps1", "IntegrationRuntime_5.44.8984.1.msi"); `
    foreach ($file in $files) { `
        $url = "https://$env:STORAGE_ACCOUNT_NAME.blob.core.windows.net/$env:CONTAINER_NAME/$file"; `
        Invoke-WebRequest -Uri $url -Headers $headers -OutFile "C:\SHIR\$file"; `
    }

# Run the build script
RUN ["powershell", "C:/SHIR/build.ps1"]

# Set the entry point to the setup script
ENTRYPOINT ["powershell", "C:/SHIR/setup.ps1"]

# Set environment variable for SHIR
ENV SHIR_WINDOWS_CONTAINER_ENV True

# Health check
HEALTHCHECK --start-period=120s CMD ["powershell", "C:/SHIR/health-check.ps1"]
