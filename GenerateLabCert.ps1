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

# Environment Variables
switch ($env:PROCESSOR_ARCHITECTURE) {
    "AMD64" { $arch = "x64" }
    "x86"   { $arch = "x86" }
    "ARM64" { $arch = "arm64" }
    default { $arch = "x64" }
}

# Check available "openssl" command
if (Get-Command "openssl" -ErrorAction SilentlyContinue) {
    $openssl = "openssl"
} elseif ($opensslPath = Get-ChildItem "openssl-*\$arch\bin\openssl.exe" -ErrorAction SilentlyContinue | Select-Object -First 1) {
    $openssl = $opensslPath.FullName
} else {
    Write-Host "[X] OpenSSL not found. Install or at openssl-*\$arch\bin\openssl.exe" -ForegroundColor Red
    exit 1
}

# Check Default Server IP
$serverIP = Get-NetIPAddress `
    -AddressFamily IPv4 `
    -PrefixOrigin DHCP,Manual `
    | Where-Object { $_.IPAddress -notlike '169.254*' -and $_.IPAddress -ne '127.0.0.1' } `
    | Select-Object -ExpandProperty IPAddress -First 1

# Show Banner 
$BANNER = @"
888               888                                     
888               888                                     
888               888                                     
888       8888b.  88888b.                                 
888          "88b 888 "88b                                
888      .d888888 888  888                                
888      888  888 888 d88P                                
88888888 "Y888888 88888P"                                 
                                                          
                                                          
                                                          
 .d8888b.                   888    888    d8P  d8b 888    
d88P  Y88b                  888    888   d8P   Y8P 888    
888    888                  888    888  d8P        888    
888         .d88b.  888d888 888888 888d88K     888 888888 
888        d8P  Y8b 888P"   888    8888888b    888 888    
888    888 88888888 888     888    888  Y88b   888 888    
Y88b  d88P Y8b.     888     Y88b.  888   Y88b  888 Y88b.  
 "Y8888P"   "Y8888  888      "Y888 888    Y88b 888  "Y888 
"@
Write-Host $BANNER -ForegroundColor "Blue"

#########
# INPUT #
#########
$input = (Read-Host "Enter rootCA Distinguished Name (Can be Any) [$rootCommonName]") -replace '^\s+|\s+$'
$rootCommonName = if ($input) { $input } else { $rootCommonName }
$input = (Read-Host "Enter Server Distinguished Name (hostname or FQDN) [$serverCommonName]") -replace '^\s+|\s+$'
$serverCommonName = if ($input) { $input } else { $serverCommonName }
$input = (Read-Host "Enter Server IP [$serverIP]") -replace '^\s+|\s+$'
$serverIP = if ($input) { $input } else { $serverIP }

######################
# FILES - rootCA.cnf #
######################
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
CN = $rootCommonName

[v3_ca]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical,CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
"@ | Out-File -FilePath $rootCnf -Encoding ascii

######################
# FILES - server.cnf #
######################
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
CN = $serverCommonName
"@ | Out-File -FilePath $serverCnf -Encoding ascii

######################
# FILES - server.ext # (Server 憑證請求檔擴展檔案)
######################
@"
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $serverCommonName
IP.1 = $serverIP
"@ | Out-File -FilePath $serverExt -Encoding ascii

# 主程式
#########################
# GENERATE - rootCA.key # (根憑證私鑰)
#########################
## RootCA
.$openssl genrsa `
    -out $rootKey $rootBit
#########################
# GENERATE - rootCA.crt # (根憑證 = 公鑰+憑證)
#########################
.$openssl req `
    -x509 -new -nodes `
    -key $rootKey -sha256 `
    -days $rootDay `
    -out $rootCrt `
    -config $rootCnf
#########################
# GENERATE - server.key # (伺服器私鑰)
#########################
.$openssl genrsa `
    -out $serverKey $serverBit
#########################
# GENERATE - server.csr # (伺服器憑證請求檔)
#########################
.$openssl req `
    -new -nodes `
    -key $serverKey `
    -out $serverCsr `
    -config $serverCnf
#########################
# GENERATE - server.crt # (伺服器 = 公鑰+憑證)
#########################
.$openssl x509 `
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
.$openssl pkcs12 `
    -export `
    -in $serverCrt `
    -inkey $serverKey `
    -out $serverPfx `
    -certfile $rootCrt `
    -passout pass:

############
# VALIDATE #
############
Write-Host "VALIDATE:" -ForegroundColor Magenta 
Write-Host "> " -NoNewline
Write-Host "'$rootCrt'" -ForegroundColor Blue
.$openssl x509 -in $rootCrt -text -noout | Select-String "Issuer:|Subject:"
Write-Host "> " -NoNewline
Write-Host "'$serverCrt'" -ForegroundColor Blue
.$openssl x509 -in $serverCrt -text -noout | Select-String "Issuer:|Subject:"
