from azure.cosmos import CosmosClient, PartitionKey
import urllib3
import os
from dotenv import load_dotenv
import requests
from unittest.mock import patch
import time

# monkeypatch requests to always disable SSL verification
original_request = requests.Session.request
def patched_request(self, *args, **kwargs):
    kwargs['verify'] = False
    return original_request(self, *args, **kwargs)

requests.Session.request = patched_request

load_dotenv()
# since cosmos db emulator uses self-signed cert, we'll disable warnings for local development (not recommended for production code)
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# cosmos db emulator defaults, not sensitive since it's local development only
# if you want to connect to the emulator from another machine, 
# set the AZURE_COSMOS_EMULATOR_IP_ADDRESS_OVERRIDE env variable to the IP address of the machine 
# running the emulator (e.g. your host machine if using docker desktop)
ENDPOINT = f"https://{os.getenv('AZURE_COSMOS_EMULATOR_IP_ADDRESS_OVERRIDE', 'localhost')}:8081/"
KEY = os.getenv("COSMOS_KEY", "C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw==") 

DB_NAME = "CarClinchDB"

CONTAINERS = [
    { "id": "dealerships",   "pk": "/id" },
    { "id": "vehicles",      "pk": "/dealerId" },
    { "id": "leads",         "pk": "/id" },
    { "id": "conversations", "pk": "/leadId" },
    { "id": "messages",      "pk": "/conversationId" }
]

# sample data to seed the database (used AI-generated data for testing, we can expand this as needed)
DEALERSHIPS = [
    {
        "id": "dealer_8c1d9f22aa",
        "name": "Example Dealership",
        "email": "dealer@example.com",
        "phone": "555-1234",
        "address1": "123 Main St",
        "address2": "",
        "city": "Ottawa",
        "province": "ON",
        "postal_code": "K1A0B1"
    },
    {
        "id": "dealer_4f92ab10c3",
        "name": "Auto World Ottawa",
        "email": "sales@autoworld.ca",
        "phone": "555-7777",
        "address1": "77 Carling Ave",
        "address2": "Unit 2",
        "city": "Ottawa",
        "province": "ON",
        "postal_code": "K2P1L4"
    }
]

VEHICLES = [
    {
        "id": "vehicle_3e9f1a2c44",
        "dealerId": "dealer_8c1d9f22aa",
        "stock_id": "A1234",
        "status": 1,
        "year": 2020,
        "vin": "1HGCM82633A123456",
        "make": "Honda",
        "model": "Civic",
        "trim": "EX",
        "mileage": "45000",
        "transmission": "Automatic",
        "comments": "Clean car"
    },
    {
        "id": "vehicle_7b2c9e11d0",
        "dealerId": "dealer_8c1d9f22aa",
        "stock_id": "B7788",
        "status": 1,
        "year": 2021,
        "vin": "2HGFA16598H123789",
        "make": "Toyota",
        "model": "Corolla",
        "trim": "SE",
        "mileage": "22000",
        "transmission": "Automatic",
        "comments": "Low mileage"
    },
    {
        "id": "vehicle_1d8f33aa91",
        "dealerId": "dealer_4f92ab10c3",
        "stock_id": "C9988",
        "status": 0,
        "year": 2019,
        "vin": "3FAHP0HA6AR123999",
        "make": "Ford",
        "model": "Fusion",
        "trim": "SEL",
        "mileage": "0",
        "transmission": "Manual",
        "comments": "No previous owners, just serviced"
    }
]

LEADS = [
  {
    "id": "lead_229fub8ss0",
    "fname": "Alice",
    "lname": "Yang",
    "email": "alice@example.com",
    "phone": "555-1111",
    "status": 0,
    "notes": "Interested in Honda Civic",
    "timestamp": "2025-02-10T15:00:00Z"
  },
  {
    "id": "lead_91ab3cd9e1",
    "fname": "John",
    "lname": "Smith",
    "email": "john.smith@example.com",
    "phone": "555-2222",
    "status": 1,
    "notes": "Asked about Toyota Corolla",
    "timestamp": "2025-02-11T10:30:00Z"
  }
]

CONVERSATIONS = [
  {
    "id": "conv_7fa22c9b0d",
    "leadId": "lead_229fub8ss0",
    "vehicleId": "vehicle_3e9f1a2c44",
    "status": 1,
    "timestamp": "2025-02-10T15:05:00Z",
  },
  {
    "id": "conv_5c1e9d22f0",
    "leadId": "lead_91ab3cd9e1",
    "vehicleId": "vehicle_7b2c9e11d0",
    "status": 1,
    "timestamp": "2025-02-10T16:00:00Z",
  },
  {
    "id": "conv_3b9e1c77aa",
    "leadId": "lead_91ab3cd9e1",
    "vehicleId": "vehicle_7b2c9e11d0",
    "status": 0,
    "timestamp": "2025-02-11T10:35:00Z",
  }
]

MESSAGES = [
  {
    "id": "msg_4fa92c1bd0",
    "conversationId": "conv_7fa22c9b0d",
    "body": "Hi Alice, thanks for your interest in the 2020 Honda Civic EX at our Ottawa dealership. It's a clean car with 45,000 km and automatic transmission. Let me know if you'd like more details or want to schedule a visit.",
    "source": 0,
    "emailMessageIdRef": "<msg9001@example.com>",
    "emailThreadId": None,
    "timestamp": "2025-02-10T15:00:30Z"
  },
  {
    "id": "msg_b1e93f77aa",
    "conversationId": "conv_7fa22c9b0d",
    "body": "Hi, I'm interested in the Honda Civic.",
    "source": 1,
    "emailMessageIdRef": "<msg9001@example.com>",
    "emailThreadId": "acs-thread-7fa22c9b0d",
    "timestamp": "2025-02-10T15:06:00Z"
  },
  {
    "id": "msg_9c2e1f44cc",
    "conversationId": "conv_7fa22c9b0d",
    "body": "Great to hear, Alice! Are you available this week to come by and take a look at the Civic?",
    "source": 0,
    "emailMessageIdRef": "<msg9002@example.com>",
    "emailThreadId": "acs-thread-7fa22c9b0d",
    "timestamp": "2025-02-10T15:07:00Z"
  },
  {
    "id": "msg_7de01abf32",
    "conversationId": "conv_7fa22c9b0d",
    "body": "Yes, I’m free on Thursday afternoon. Does that work?",
    "source": 1,
    "emailMessageIdRef": "<msg9002@example.com>",
    "emailThreadId": "acs-thread-7fa22c9b0d",
    "timestamp": "2025-02-10T15:09:30Z"
  },
  {
    "id": "msg_f0a3c9e811",
    "conversationId": "conv_7fa22c9b0d",
    "body": "Thursday works perfectly. I’ve booked you for 3:00 PM at 123 Main St, Ottawa. Looking forward to seeing you!",
    "source": 0,
    "emailMessageIdRef": "<msg9003@example.com>",
    "emailThreadId": "acs-thread-7fa22c9b0d",
    "timestamp": "2025-02-10T15:10:10Z"
  },
  {
    "id": "msg_2b94ef77d9",
    "conversationId": "conv_7fa22c9b0d",
    "body": "Great, thank you! See you then.",
    "source": 1,
    "emailMessageIdRef": "<msg9003@example.com>",
    "emailThreadId": "acs-thread-7fa22c9b0d",
    "timestamp": "2025-02-10T15:11:00Z"
  },

  {
    "id": "msg_8c1f22bb04",
    "conversationId": "conv_5c1e9d22f0",
    "body": "Hi John, thanks for reaching out about the 2021 Toyota Corolla SE. It has only 22,000 km and is in great condition. Let me know if you'd like to come by our Ottawa location to take a look.",
    "source": 0,
    "emailMessageIdRef": "<msg9100@example.com>",
    "emailThreadId": None,
    "timestamp": "2025-02-11T10:30:20Z"
  },
  {
    "id": "msg_3e9d11ac72",
    "conversationId": "conv_5c1e9d22f0",
    "body": "Is the Corolla still available?",
    "source": 1,
    "emailMessageIdRef": "<msg9100@example.com>",
    "emailThreadId": "acs-thread-5c1e9d22f0",
    "timestamp": "2025-02-11T10:31:00Z"
  },

  {
    "id": "msg_5bd0f9aa13",
    "conversationId": "conv_3b9e1c77aa",
    "body": "Hi John, thanks for your interest in the Ford Fusion SEL. It was recently serviced and is in good shape. Let me know if you'd like to arrange a viewing.",
    "source": 0,
    "emailMessageIdRef": "<msg9200@example.com>",
    "emailThreadId": None,
    "timestamp": "2025-02-11T10:35:00Z"
  },
  {
    "id": "msg_c7e12f44b8",
    "conversationId": "conv_3b9e1c77aa",
    "body": "Thanks for the info. Is it still available?",
    "source": 1,
    "emailMessageIdRef": "<msg9200@example.com>",
    "emailThreadId": "acs-thread-3b9e1c77aa",
    "timestamp": "2025-02-11T10:35:40Z"
  },
  {
    "id": "msg_e4b82a19cc",
    "conversationId": "conv_3b9e1c77aa",
    "body": "Hi John, yes the Fusion is available.",
    "source": 0,
    "emailMessageIdRef": "<msg9201@example.com>",
    "emailThreadId": "acs-thread-3b9e1c77aa",
    "timestamp": "2025-02-11T10:36:00Z"
  }
]


# custom stored procedures for cascade delete functionality 
# since cosmos db doesn't support this natively, we have to implement it ourselves in the app layer
# run this in app code INSTEAD of the normal delete operation (.delete_item) to ensure related documents are also deleted
# otherwise you may end up with orphaned documents in your database

# stored procedures are kept in the container that holds the children you need to delete

# ex. delete conversation and all related messages for a lead
"""
conversations_container.scripts.execute_stored_procedure(
    "cascadeDeleteConversation",
    partition_key="conv_501",
    params=["conv_501"]
)
"""
# ex. delete lead and all related conversations and messages
"""
leads_container.scripts.execute_stored_procedure(
    "cascadeDeleteLead",
    partition_key="lead_555",
    params=["lead_555"] 
"""

CASCADE_DELETE_CONVERSATION = """
function cascadeDeleteConversation(conversationId) {
    var collection = getContext().getCollection();
    var response = getContext().getResponse();

    var query = {
        query: "SELECT * FROM c WHERE c.conversationId = @cid",
        parameters: [{ name: "@cid", value: conversationId }]
    };

    var docs = [];

    var accepted = collection.queryDocuments(
        collection.getSelfLink(),
        query,
        function (err, feed) {
            if (err) throw err;

            docs = feed;
            deleteDocs();
        }
    );

    if (!accepted) throw new Error("Query not accepted");

    function deleteDocs() {
        if (docs.length === 0) {
            response.setBody("Cascade delete complete");
            return;
        }

        var doc = docs.pop();

        var accepted = collection.deleteDocument(
            doc._self,
            function (err) {
                if (err) throw err;
                deleteDocs();
            }
        );

        if (!accepted) throw new Error("Delete not accepted");
    }
}
"""

CASCADE_DELETE_LEAD = """
function cascadeDeleteLead(leadId) {
    var collection = getContext().getCollection();
    var response = getContext().getResponse();

    var query = {
        query: "SELECT * FROM c WHERE c.leadId = @lid",
        parameters: [{ name: "@lid", value: leadId }]
    };

    var docs = [];

    var accepted = collection.queryDocuments(
        collection.getSelfLink(),
        query,
        function (err, feed) {
            if (err) throw err;

            docs = feed;
            deleteDocs();
        }
    );

    if (!accepted) throw new Error("Query not accepted");

    function deleteDocs() {
        if (docs.length === 0) {
            response.setBody("Cascade delete complete");
            return;
        }

        var doc = docs.pop();

        var accepted = collection.deleteDocument(
            doc._self,
            function (err) {
                if (err) throw err;
                deleteDocs();
            }
        );

        if (!accepted) throw new Error("Delete not accepted");
    }
}
"""

def main():
    print("Connecting to Cosmos DB Emulator...")
    client = CosmosClient(ENDPOINT, KEY, connection_verify=False)

    print(f"Ensuring database '{DB_NAME}' exists...")
    db = client.create_database_if_not_exists(id=DB_NAME)

    # create containers
    for c in CONTAINERS:
        print(f"Ensuring container '{c['id']}' exists with PK '{c['pk']}'...")
        container = db.create_container_if_not_exists(
            id=c["id"],
            partition_key=PartitionKey(path=c["pk"])
        )
        # time.sleep(3)
        print(f"Container '{c['id']}' is ready.")
        # upload stored procedures where relevant
        if c["id"] == "messages":
            try:
                container.scripts.delete_stored_procedure("cascadeDeleteConversation")
            except:
                pass 
            print("Uploading cascadeDeleteConversation stored procedure...")
            container.scripts.create_stored_procedure({
                "id": "cascadeDeleteConversation",
                "body": CASCADE_DELETE_CONVERSATION
            })

        if c["id"] == "conversations":
            try:
                container.scripts.delete_stored_procedure("cascadeDeleteLead")
            except:
                pass
            print("Uploading cascadeDeleteLead stored procedure...")
            container.scripts.create_stored_procedure({
                "id": "cascadeDeleteLead",
                "body": CASCADE_DELETE_LEAD
            })
        


    # seed dealerships
    dealerships_container = db.get_container_client("dealerships")
    for d in DEALERSHIPS:
        dealerships_container.upsert_item(d)

    # seed vehicles
    vehicles_container = db.get_container_client("vehicles")
    for v in VEHICLES:
        vehicles_container.upsert_item(v)
        
    # # seed leads
    # leads_container = db.get_container_client("leads")
    # for l in LEADS:
    #     leads_container.upsert_item(l)
        
    # # seed conversations
    # conversations_container = db.get_container_client("conversations")
    # for c in CONVERSATIONS:
    #     conversations_container.upsert_item(c)
        
    # # seed messages
    # messages_container = db.get_container_client("messages")
    # for m in MESSAGES:
    #     messages_container.upsert_item(m)

    print("Seeding complete.")

if __name__ == "__main__":
    main()
