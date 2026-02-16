# Quick Reference Guide: CosmosDB (NoSQL) + Docker/Installer (Windows)

This QRG will have you set up Cosmos DB emulator and also seeds the DB with a script that inits all containers and seed vehicles and dealerships.

## 1. Start/Install CosmosDB Emulator

Follow the instructions for the options here: [Cosmos DB Emulator Setup](https://learn.microsoft.com/en-us/azure/cosmos-db/how-to-develop-emulator?tabs=windows%2Ccsharp&pivots=api-nosql)

IMO if you have Windows, use the installer. If you have Linux, use Docker. The Windows Docker image is extremely heavy.

---

## 2. Init the containers

### 1. Activate your virtual environment and install dependencies.

macOS/Linux
```bash
source .venv/bin/activate
pip install -r requirements.txt
```

Windows
```bash
.venv\Scripts\activate
pip install -r requirements.txt
```

### 2. Run the script to init containers & seed data:
```bash
python init.py
```

### 3. Navigate to the following:
```
https://localhost:8081/_explorer/index.html
```

TADA!!

![alt text](images/image.png)

## 3. Stored Procedures: Cascade Deletes for Leads & Conversations

To safely delete related data (eg deleting a lead -> delete its conversations -> delete their messages), I made two stored procedures that perform the required cascading deletes. Cosmos DB stored procedures can only operate within one container and one partition key value.

These stored procedures ensure our data stays clean and consistent like in a more strict SQL DB w/o having to manually manage multi‑step deletes in our app code and ensuring no orphaned conversations or messages.

### `cascadeDeleteConversation` (messages container)
**Purpose:** delete all messages belonging to a single conversation.

Messages are partitioned by:

```
/conversationId
```

So to delete all messages for a conversation, the stored procedure must run **inside the messages container**, scoped to that conversation’s partition.

**Example:** delete conversation and all related messages for a lead in Python script w/ Cosmos DB SDK
```python
from azure.cosmos import CosmosClient

client = CosmosClient(ENDPOINT, KEY)
db = client.get_database_client("carclinch")
messages = db.get_container_client("messages")

result = messages.scripts.execute_stored_procedure(
    sproc="cascadeDeleteConversation",
    partition_key="conv_501",
    params=["conv_501"]
)

print(result)
```

---

### `cascadeDeleteLead` (conversations container)

**Purpose:** delete all conversations belonging to a lead and trigger message deletion for each conversation.

Conversations are partitioned by:

```
/leadId
```

So to delete all conversations for a lead, the stored procedure must run **inside the conversations container**, scoped to that lead’s partition.

**Example:** delete lead, all related conversations, and each conversations' related messages in Python script w/ Cosmos DB SDK
```python
from azure.cosmos import CosmosClient

client = CosmosClient(ENDPOINT, KEY)
db = client.get_database_client("carclinch")
messages = db.get_container_client("conversations")

result = messages.scripts.execute_stored_procedure(
    sproc="cascadeDeleteLead",
    partition_key="lead_555",
    params=["lead_555"]
)

print(result)
```

This gives you a full cascade:

```
Lead -> Conversations -> Messages
```