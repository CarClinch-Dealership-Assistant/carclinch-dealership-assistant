# Docker Compose - EVERYTHING!!!

## Env Setup

Copy contents of `.env.copy` into `.env`.
To find the OPENAI env variables, make sure to create the Foundry resource, deploy the gpt-4.1-mini model, and find the values in `Foundry` -> `Playgrounds` -> `View Code` -> Scroll down and copy paste the key and URL values.

Create an app password for your personal Gmail inbox by going to `Manage your Google Account` -> `Security & sign-in` -> Search `App passwords` -> Create a new one. OR use the one I shared with the team before.

The GMAIL values are your email address and that created app password with no spaces.

Then:

```bash
# start venv from cosmosdb
source cosmosdb/.venv/Scripts/activate
```

## Docker Compose

Activate venv and in `/infra/local`:
```bash
docker compose up -d
```

## Seed DB

Activate .venv, then:
```bash
py init.py
```

## Navigate

### CosmosDB: Bypass Certificate

If none of the above certificate assignment works, go to:

https://localhost:8081/_explorer/index.html

And click the following options:

<img width="1342" height="850" alt="image" src="https://github.com/user-attachments/assets/1ec4a030-8009-46ef-9887-ff1f1ea29882" />

### Form Frontend 

http://localhost:8080/
