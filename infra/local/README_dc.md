# Docker Compose - EVERYTHING!!!

## Env Setup

Copy contents of `.env.copy` into `.env`. To run the `init.py` script, be sure to set the `AZURE_COSMOS_EMULATOR_IP_ADDRESS_OVERRIDE` to your machine's LAN IP. You can find it by running:

```bash
ipconfig
```

Then:

```bash
# start venv from cosmosdb
source cosmosdb/.venv/Scripts/activate
```

## Docker Compose

```bash
cd infra/local
docker compose up -d
```

## Install Certificate for Cosmos DB Emulator

To access the browser explorer for Cosmos DB emulator:

https://localhost:8081/_explorer/index.html

You must install one of the certificates located in /certs

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

## Seed DB

Make sure to set `AZURE_COSMOS_EMULATOR_IP_ADDRESS_OVERRIDE` to your local IP esp on Windows.

```bash
py init.py
```

## Navigate

### CosmosDB: Bypass Certificate

If none of the above certificate assignment works, go to:

https://localhost:8081/_explorer/index.html

And click the following options:

<img width="1342" height="850" alt="image" src="https://github.com/user-attachments/assets/1ec4a030-8009-46ef-9887-ff1f1ea29882" />

### Web Form

http://localhost:8080/
