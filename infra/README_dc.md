# Docker Compose - EVERYTHING!!!

## Docker Compose

```bash
docker compose up -d
```

## Install Certificate for Cosmos DB Emulator

To access the browser explorer for Cosmos DB emulator:

```bash
https://localhost:8081/_explorer/index.html
```

You must install one of the certificates located in /certs. 

### Windows

1. Double-click `emulatorcert.crt`
2. Choose `Local Machine`

3. Choose `Place all certificates in the following store`

Click `Browse…` and select:

```
Trusted Root Certification Authorities
```

1. Finish -> Yes (to trust the certificate)

Once installed, Windows trusts the Cosmos Emulator’s HTTPS certificate.

### macOS

```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain emulator.pem
```

### Linux (Ubuntu/Debian)

```bash
sudo cp emulator.pem /usr/local/share/ca-certificates/emulator.crt
sudo update-ca-certificates
```