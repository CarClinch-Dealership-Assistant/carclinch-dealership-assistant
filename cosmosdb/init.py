from azure.cosmos import CosmosClient, PartitionKey
import urllib3

# since cosmos db emulator uses self-signed cert, we'll disable warnings for local development (not recommended for production code)
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# cosmos db emulator defaults, not sensitive since it's local development only
ENDPOINT = "https://localhost:8081"
KEY = "C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw==" 

DB_NAME = "carclinch"

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
        "mileage": "60000",
        "transmission": "Manual",
        "comments": "Recently serviced"
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
    "wants_email": True,
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
    "wants_email": False,
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
    "leadId": "lead_229fub8ss0",
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
    "id": "msg_4d9f22aa10",
    "conversationId": "conv_7fa22c9b0d",
    "body": "Hi, I'm interested in the Honda Civic.",
    "source": 1,
    "in_reply_to": None,
    "email_thread": None,
    "message_identifier": "<msg9001@example.com>",
    "timestamp": "2025-02-10T15:06:00Z"
  },
  {
    "id": "msg_8c22ab19f1",
    "conversationId": "conv_7fa22c9b0d",
    "body": "Thanks Alice! When would you like to come in?",
    "source": 0,
    "in_reply_to": "<msg9001@example.com>",
    "email_thread": None,
    "message_identifier": "<msg9002@example.com>",
    "timestamp": "2025-02-10T15:07:00Z"
  },
  {
    "id": "msg_1a9e3c77bb",
    "conversationId": "conv_5c1e9d22f0",
    "body": "Is the Corolla still available?",
    "source": 1,
    "in_reply_to": None,
    "email_thread": None,
    "message_identifier": "<msg9100@example.com>",
    "timestamp": "2025-02-10T16:01:00Z"
  },
  {
    "id": "msg_9b2e1f44cc",
    "conversationId": "conv_3b9e1c77aa",
    "body": "Hi John, yes the Corolla is available.",
    "source": 0,
    "in_reply_to": None,
    "email_thread": None,
    "message_identifier": "<msg9200@example.com>",
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
    client = CosmosClient(ENDPOINT, KEY)

    print(f"Ensuring database '{DB_NAME}' exists...")
    db = client.create_database_if_not_exists(id=DB_NAME)

    # create containers
    for c in CONTAINERS:
        print(f"Ensuring container '{c['id']}' exists with PK '{c['pk']}'...")
        container = db.create_container_if_not_exists(
            id=c["id"],
            partition_key=PartitionKey(path=c["pk"])
        )
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
        
    # seed leads
    leads_container = db.get_container_client("leads")
    for l in LEADS:
        leads_container.upsert_item(l)
        
    # seed conversations
    conversations_container = db.get_container_client("conversations")
    for c in CONVERSATIONS:
        conversations_container.upsert_item(c)
        
    # seed messages
    messages_container = db.get_container_client("messages")
    for m in MESSAGES:
        messages_container.upsert_item(m)

    print("Seeding complete.")

if __name__ == "__main__":
    main()
