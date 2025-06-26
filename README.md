# LabCertKit 🔐

A PowerShell toolkit for generating SSL/TLS certificates for lab environments and local development. This toolkit provides both an interactive script and a command-line interface for creating self-signed certificates with proper Subject Alternative Names (SAN) configuration.

## Features

- 🏗️ **Root CA Generation**: Create your own Certificate Authority for lab environments
- 🖥️ **Server Certificates**: Generate server certificates signed by your Root CA
- 📦 **PFX Bundle**: Automatically create PKCS#12 format for easy deployment
- 🌐 **SAN Support**: Includes both DNS names and IP addresses in certificates
- 🔧 **Cross-Platform**: Works on Windows, Linux, and macOS with PowerShell
- 📋 **Multiple Interfaces**: Interactive script and command-line tool

## Prerequisites

- **PowerShell**: 5.1 or later (PowerShell Core 6+ recommended for cross-platform)
- **OpenSSL**: Must be available in one of these ways:
  - Installed and available in PATH
  - Located in `openssl-*\{arch}\bin\openssl.exe` relative to script directory

### Installing OpenSSL

**Windows:**
```powershell
# Using Chocolatey
choco install openssl

# Using Scoop
scoop install openssl

# Or download for each arch installation package from: https://slproweb.com/products/Win32OpenSSL.html
# Or download for x64 arch installation package from: https://kb.firedaemon.com/support/solutions/articles/4000121705
# Or download for portable zip: https://kb.firedaemon.com/support/solutions/articles/4000121705
```

**Linux/macOS:**
```bash
# Ubuntu/Debian
sudo apt-get install openssl

# CentOS/RHEL
sudo yum install openssl

# macOS with Homebrew
brew install openssl
```

**All Version:**
```bash
# Source Code on OpenSSL Github Release from: https://github.com/openssl/openssl/releases/latest
# Source Code on OpenSSL Library ORG from: https://openssl-library.org/source/
# Follow INSTALL.md to install from: https://github.com/openssl/openssl/blob/master/INSTALL.md
```

## Scripts Overview

### 1. GenerateLabCert.ps1
Interactive script that guides you through certificate generation with prompts.

### 2. LabCertKit.ps1
Command-line interface with subcommands for automated certificate management.

## Quick Start

### Interactive Mode (GenerateLabCert.ps1)
```powershell
# Run the interactive script
.\GenerateLabCert.ps1

# Follow the prompts:
# - Enter Root CA name (default: uniXecureLab)
# - Enter server hostname/FQDN (default: current hostname)
# - Enter server IP address (auto-detected)
```

### Command-Line Mode (LabCertKit.ps1)
```powershell
# Create all certificates (Root CA + Server)
.\LabCertKit.ps1 create all

# Create only server certificates (requires existing Root CA)
.\LabCertKit.ps1 create server

# Remove all certificate files
.\LabCertKit.ps1 remove all

# Show help
.\LabCertKit.ps1 -h
.\LabCertKit.ps1 create -h
```

## Generated Files

| File | Description | Usage |
|------|-------------|-------|
| `rootCA.key` | Root CA private key | Keep secure! Used to sign server certificates |
| `rootCA.crt` | Root CA certificate | Install in trusted root store |
| `rootCA.cnf` | Root CA configuration | OpenSSL configuration file |
| `server.key` | Server private key | Web server private key |
| `server.crt` | Server certificate | Web server certificate |
| `server.csr` | Certificate signing request | Intermediate file (can be deleted) |
| `server.pfx` | PKCS#12 bundle | Contains server cert + key + CA cert |
| `server.ext` | Server extensions | SAN configuration for server cert |
| `server.cnf` | Server configuration | OpenSSL configuration file |

## Certificate Details

### Root CA Certificate
- **Key Size**: 4096 bits RSA
- **Validity**: 10 years (3650 days)
- **Hash Algorithm**: SHA-256
- **Extensions**: CA:TRUE, Key Cert Sign, CRL Sign

### Server Certificate
- **Key Size**: 2048 bits RSA
- **Validity**: 10 years (3650 days)
- **Hash Algorithm**: SHA-256
- **Extensions**: Digital Signature, Key Encipherment, Data Encipherment
- **SAN**: DNS name and IP address included

## Usage Examples

### Web Server Configuration

**IIS (Windows):**
1. Import `server.pfx` into Local Machine\Personal store
2. Bind certificate to website in IIS Manager

**Apache:**
```apache
SSLCertificateFile /path/to/server.crt
SSLCertificateKeyFile /path/to/server.key
SSLCACertificateFile /path/to/rootCA.crt
```

**Nginx:**
```nginx
ssl_certificate /path/to/server.crt;
ssl_certificate_key /path/to/server.key;
```

### Client Trust Configuration

**Windows:**
```powershell
# Import Root CA to Trusted Root Certification Authorities
Import-Certificate -FilePath "rootCA.crt" -CertStoreLocation "Cert:\LocalMachine\Root"
```

**Linux/macOS:**
```bash
# Copy to system trust store (path varies by distribution)
sudo cp rootCA.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates  # Ubuntu/Debian

# Or for single application
curl --cacert rootCA.crt https://your-server.com
```

## Command Reference

### LabCertKit.ps1 Commands

```powershell
# General help
.\LabCertKit.ps1 -h

# Create certificates
.\LabCertKit.ps1 create all      # Root CA + Server certificates
.\LabCertKit.ps1 create server   # Server certificates only

# Remove certificates
.\LabCertKit.ps1 remove all      # Remove all certificate files

# Command-specific help
.\LabCertKit.ps1 create -h
.\LabCertKit.ps1 remove -h
```

## Security Considerations

⚠️ **Important Security Notes:**

1. **Lab Use Only**: These certificates are for development and lab environments
2. **Private Key Security**: Keep `rootCA.key` secure - it can sign new certificates
3. **Root CA Distribution**: Only install Root CA on systems you control
4. **Production Warning**: Do not use self-signed certificates in production environments
5. **Key Rotation**: Regenerate certificates periodically

## Troubleshooting

### Common Issues

**OpenSSL Not Found:**
```
[X] OpenSSL not found. Install or at openssl-*\x64\bin\openssl.exe
```
- Install OpenSSL or place it in the expected directory structure

**Permission Denied:**
```powershell
# Enable script execution
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Certificate Validation Errors:**
- Ensure hostname/IP matches certificate SAN entries
- Verify Root CA is installed in trusted store
- Check certificate expiration dates

### Validation Commands

```powershell
# Verify certificate details
openssl x509 -in server.crt -text -noout

# Check certificate chain
openssl verify -CAfile rootCA.crt server.crt

# Test HTTPS connection
openssl s_client -connect localhost:443 -CAfile rootCA.crt
```

## Development

### Contributing
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on multiple platforms
5. Submit a pull request

### Testing
```powershell
# Test certificate generation
.\LabCertKit.ps1 create all

# Validate generated certificates
openssl verify -CAfile rootCA.crt server.crt

# Clean up
.\LabCertKit.ps1 remove all
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Built for uniXecure lab environments
- Inspired by the need for easy SSL certificate generation in development workflows
- Uses OpenSSL for all cryptographic operations

---

**⚡ Quick Commands:**
```powershell
# One-liner for complete setup
.\LabCertKit.ps1 create all

# Import Root CA to Windows trust store
Import-Certificate -FilePath "rootCA.crt" -CertStoreLocation "Cert:\LocalMachine\Root"
```