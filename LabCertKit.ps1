#!/usr/bin/env pwsh

param(
    [Parameter(Position = 0)]
    [string]$Command,
    
    [Parameter(Position = 1)]
    [string]$SubCommand,
    
    [switch]$h,
    [switch]$help
)

# Variables
$rootCommonName = "MyLab"
$rootKey = "rootCA.key"
$rootCrt = "rootCA.crt"
$rootCnf = "rootCA.cnf"
$rootBit = 4096
$rootDay = 3650
$serverCommonName = $(hostname)
$serverKey = "server.key"
$serverCsr = "server.csr"
$serverCrt = "server.crt"
$serverPfx = "server.pfx"
$serverExt = "server.ext"
$serverCnf = "server.cnf"
$serverBit = 2048
$serverDay = 3650

function Get-ScriptName {
    return (Get-Item $MyInvocation.ScriptName).BaseName
}

function Show-Banner {
    $BANNER = @"
888               888                                     
888               888                                     
888               888                                     
888       8888b.  88888b.                                 
888          "88b 888 "88b                                
888      .d888888 888  888                                
888      888  888 888 d88P                                
88888888 "Y888888 88888P"                                 
                                                          
                                                          
                                                          
 .d8888b.                   888    888    d8b 888    
d88P  Y88b                  888    888   d8P   Y8P 888    
888    888                  888    888  d8P        888    
888         .d88b.  888d888 888888 888d88K     888 888888 
888        d8P  Y8b 888P"   888    8888888b    888 888    
888    888 88888888 888     888    888  Y88b   888 888    
Y88b  d88P Y8b.     888     Y88b.  888   Y88b  888 Y88b.  
 "Y8888P"   "Y8888  888      "Y888 888    Y88b 888  "Y888 
"@
    Write-Host $BANNER -ForegroundColor "Blue"
}

function Initialize-Environment {
    # Environment Variables
    switch ($env:PROCESSOR_ARCHITECTURE) {
        "AMD64" { $script:arch = "x64" }
        "x86"   { $script:arch = "x86" }
        "ARM64" { $script:arch = "arm64" }
        default { $script:arch = "x64" }
    }

    # Check available "openssl" command
    if (Get-Command "openssl" -ErrorAction SilentlyContinue) {
        $script:openssl = "openssl"
    } elseif ($opensslPath = Get-ChildItem "openssl-*\$script:arch\bin\openssl.exe" -ErrorAction SilentlyContinue | Select-Object -First 1) {
        $script:openssl = $opensslPath.FullName
    } else {
        Write-Host "[X] OpenSSL not found. Install or at openssl-*\$script:arch\bin\openssl.exe" -ForegroundColor Red
        exit 1
    }

    # Check Default Server IP
    $script:serverIP = Get-NetIPAddress `
        -AddressFamily IPv4 `
        -PrefixOrigin DHCP,Manual `
        | Where-Object { $_.IPAddress -notlike '169.254*' -and $_.IPAddress -ne '127.0.0.1' } `
        | Select-Object -ExpandProperty IPAddress -First 1
}

function Get-UserInput {
    param(
        [bool]$ServerOnly = $false
    )
    
    if (-not $ServerOnly) {
        $input = (Read-Host "Enter rootCA Distinguished Name (Can be Any) [$script:rootCommonName]") -replace '^\s+|\s+$'
        $script:rootCommonName = if ($input) { $input } else { $script:rootCommonName }
    }
    
    $input = (Read-Host "Enter Server Distinguished Name (hostname or FQDN) [$script:serverCommonName]") -replace '^\s+|\s+$'
    $script:serverCommonName = if ($input) { $input } else { $script:serverCommonName }
    $input = (Read-Host "Enter Server IP [$script:serverIP]") -replace '^\s+|\s+$'
    $script:serverIP = if ($input) { $input } else { $script:serverIP }
}

function Create-ConfigFiles {
    param(
        [bool]$ServerOnly = $false
    )
    
    if (-not $ServerOnly) {
        # Create rootCA.cnf
        @"
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no

[req_distinguished_name]
C = TW
ST = Taiwan
L = Taipei
O = MyLab
OU = IT
CN = $script:rootCommonName

[v3_ca]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical,CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
"@ | Out-File -FilePath $rootCnf -Encoding ascii
    }

    # Create server.cnf
    @"
[req]
distinguished_name = req_distinguished_name
prompt = no

[req_distinguished_name]
C = TW
ST = Taiwan
L = Taipei
O = MyLab
OU = IT
CN = $script:serverCommonName
"@ | Out-File -FilePath $serverCnf -Encoding ascii

    # Create server.ext
    @"
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $script:serverCommonName
IP.1 = $script:serverIP
"@ | Out-File -FilePath $serverExt -Encoding ascii
}

function Generate-RootCA {
    Write-Host "Creating Root CA..." -ForegroundColor Green
    
    #########################
    # GENERATE - rootCA.key # (根憑證私鑰)
    #########################
    Write-Host "|-- Generating Root CA private key" -ForegroundColor Gray
    & $script:openssl genrsa `
        -out $rootKey $rootBit
    
    #########################
    # GENERATE - rootCA.crt # (根憑證 = 公鑰+憑證)
    #########################
    Write-Host "|-- Creating Root CA certificate" -ForegroundColor Gray
    & $script:openssl req `
        -x509 -new -nodes `
        -key $rootKey -sha256 `
        -days $rootDay `
        -out $rootCrt `
        -config $rootCnf
}

function Generate-ServerCertificates {
    Write-Host "Creating Server certificates..." -ForegroundColor Green
    
    #########################
    # GENERATE - server.key # (伺服器私鑰)
    #########################
    Write-Host "|-- Generating server private key" -ForegroundColor Gray
    & $script:openssl genrsa `
        -out $serverKey $serverBit
    
    #########################
    # GENERATE - server.csr # (伺服器憑證請求檔)
    #########################
    Write-Host "|-- Creating server certificate signing request" -ForegroundColor Gray
    & $script:openssl req `
        -new -nodes `
        -key $serverKey `
        -out $serverCsr `
        -config $serverCnf
    
    #########################
    # GENERATE - server.crt # (伺服器 = 公鑰+憑證)
    #########################
    Write-Host "|-- Signing server certificate" -ForegroundColor Gray
    & $script:openssl x509 `
        -req `
        -in $serverCsr `
        -CA $rootCrt `
        -CAkey $rootKey `
        -CAcreateserial `
        -out $serverCrt `
        -days $serverDay `
        -sha256 `
        -extfile $serverExt
    
    #########################
    # GENERATE - server.pfx # (個人信息交換檔案 = 私鑰+公鑰+憑證)
    #########################
    Write-Host "|-- Creating PFX bundle" -ForegroundColor Gray
    & $script:openssl pkcs12 `
        -export `
        -in $serverCrt `
        -inkey $serverKey `
        -out $serverPfx `
        -certfile $rootCrt `
        -passout pass:
}

function Show-ValidationInfo {
    Write-Host ""
    Write-Host "VALIDATE:" -ForegroundColor Magenta 
    Write-Host "> " -NoNewline
    Write-Host "'$rootCrt'" -ForegroundColor Blue
    & $script:openssl x509 -in $rootCrt -text -noout | Select-String "Issuer:|Subject:|IP Address"
    Write-Host "> " -NoNewline
    Write-Host "'$serverCrt'" -ForegroundColor Blue
    & $script:openssl x509 -in $serverCrt -text -noout | Select-String "Issuer:|Subject:|IP Address"
    Write-Host "> " -NoNewline
    Write-Host "'$serverPfx'" -ForegroundColor Blue
    & $script:openssl x509 -in $serverCrt -text -noout | Select-String "Issuer:|Subject:|IP Address"
    Write-Host ""
}

function Show-GeneralHelp {
    $scriptName = Get-ScriptName
    Write-Host "$scriptName - Certificate Management Tool" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "    $scriptName [COMMAND] [OPTIONS]"
    Write-Host ""
    Write-Host "COMMANDS:" -ForegroundColor Yellow
    Write-Host "    create      Create certificates"
    Write-Host "    remove      Remove certificates"
    Write-Host ""
    Write-Host "OPTIONS:" -ForegroundColor Yellow
    Write-Host "    -h, --help  Show help information"
    Write-Host ""
    Write-Host "Use '$scriptName [COMMAND] -h' for more information about a command." -ForegroundColor Gray
    Write-Host ""
}

function Show-CreateHelp {
    $scriptName = Get-ScriptName
    Write-Host "$scriptName create - Create certificates" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "    $scriptName create [SUBCOMMAND]"
    Write-Host ""
    Write-Host "SUBCOMMANDS:" -ForegroundColor Yellow
    Write-Host "    all         Create all certificates (Root CA + Server certificates)"
    Write-Host "    server      Create server certificates only (requires existing Root CA)"
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "    $scriptName create all      # Create Root CA and Server certificates"
    Write-Host "    $scriptName create server   # Create only server certificates"
    Write-Host ""
}

function Show-RemoveHelp {
    $scriptName = Get-ScriptName
    Write-Host "$scriptName remove - Remove certificates" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "    $scriptName remove [SUBCOMMAND]"
    Write-Host ""
    Write-Host "SUBCOMMANDS:" -ForegroundColor Yellow
    Write-Host "    all         Remove all certificate files and configurations"
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "    $scriptName remove all      # Remove all certificate files"
    Write-Host ""
}

function Invoke-CreateAll {
    Show-Banner
    Initialize-Environment
    Get-UserInput -ServerOnly $false
    Create-ConfigFiles -ServerOnly $false
    Generate-RootCA
    Generate-ServerCertificates
    Write-Host "\-- Certificate creation completed!" -ForegroundColor Green
    Show-ValidationInfo
}

function Invoke-CreateServer {
    Show-Banner
    Initialize-Environment
    
    # Check if Root CA exists
    if (-not (Test-Path $rootCrt) -or -not (Test-Path $rootKey)) {
        Write-Host "[X] Root CA not found. Please run 'create all' first or ensure $rootCrt and $rootKey exist." -ForegroundColor Red
        exit 1
    }
    
    Get-UserInput -ServerOnly $true
    Create-ConfigFiles -ServerOnly $true
    Generate-ServerCertificates
    Write-Host "\-- Server certificate creation completed!" -ForegroundColor Green
    
    # Show validation for server cert only
    Write-Host ""
    Write-Host "VALIDATE:" -ForegroundColor Magenta 
    Write-Host "> " -NoNewline
    Write-Host "'$serverCrt'" -ForegroundColor Blue
    & $script:openssl x509 -in $serverCrt -text -noout | Select-String "Issuer:|Subject:|IP Address"
    Write-Host "> " -NoNewline
    Write-Host "'$serverPfx'" -ForegroundColor Blue
    & $script:openssl x509 -in $serverCrt -text -noout | Select-String "Issuer:|Subject:|IP Address"
    Write-Host ""
}

function Invoke-RemoveAll {
    Write-Host "Removing all certificates and configuration files..." -ForegroundColor Red
    
    $filesToRemove = @("*.cnf", "*.ext", "*.key", "*.crt", "*.csr", "*.srl", "*.pfx")
    
    foreach ($pattern in $filesToRemove) {
        $files = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue
        if ($files) {
            Write-Host "|-- Removing $($files.Count) $pattern file(s)" -ForegroundColor Gray
            $files | Remove-Item -Force
        }
    }
    
    Write-Host "\-- All certificate files removed!" -ForegroundColor Red
}

# Main execution logic
# Handle help requests first
if ($h -or $help -or $Command -eq "--help" -or $Command -eq "-h") {
    if ([string]::IsNullOrEmpty($Command) -or $Command -eq "--help" -or $Command -eq "-h") {
        Show-GeneralHelp
    } elseif ($Command -eq "create") {
        Show-CreateHelp
    } elseif ($Command -eq "remove") {
        Show-RemoveHelp
    }
    exit 0
}

# Handle no arguments - show general help
if ([string]::IsNullOrEmpty($Command)) {
    Show-GeneralHelp
    exit 0
}

# Handle commands
switch ($Command.ToLower()) {
    "create" {
        # Check if help is requested for create command
        if ($SubCommand -eq "-h" -or $SubCommand -eq "--help") {
            Show-CreateHelp
            exit 0
        }
        
        # Handle create subcommands
        if ([string]::IsNullOrEmpty($SubCommand)) {
            Show-CreateHelp
            exit 0
        }
        
        switch ($SubCommand.ToLower()) {
            "all" {
                Invoke-CreateAll
            }
            "server" {
                Invoke-CreateServer
            }
            default {
                Write-Host "Unknown subcommand '$SubCommand' for 'create'" -ForegroundColor Yellow
                Write-Host ""
                Show-CreateHelp
                exit 0
            }
        }
    }
    "remove" {
        # Check if help is requested for remove command
        if ($SubCommand -eq "-h" -or $SubCommand -eq "--help") {
            Show-RemoveHelp
            exit 0
        }
        
        # Handle remove subcommands
        if ([string]::IsNullOrEmpty($SubCommand)) {
            Show-RemoveHelp
            exit 0
        }
        
        switch ($SubCommand.ToLower()) {
            "all" {
                Invoke-RemoveAll
            }
            default {
                Write-Host "Unknown subcommand '$SubCommand' for 'remove'" -ForegroundColor Yellow
                Write-Host ""
                Show-RemoveHelp
                exit 0
            }
        }
    }
    default {
        Write-Host "Unknown command '$Command'" -ForegroundColor Yellow
        Write-Host ""
        Show-GeneralHelp
        exit 0
    }
}