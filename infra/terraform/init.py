"""
Cosmos DB seed script — runs against real Azure Cosmos DB (not emulator).
Called by Terraform null_resource after Cosmos is provisioned.

Usage (Terraform passes env vars automatically):
  COSMOS_ENDPOINT=<url> COSMOS_KEY=<key> COSMOS_DATABASE=<db> python init.py
"""

from azure.cosmos import CosmosClient, PartitionKey, exceptions
import os
import sys

ENDPOINT = os.environ["COSMOS_ENDPOINT"]
KEY      = os.environ["COSMOS_KEY"]
DB_NAME  = os.environ.get("COSMOS_DATABASE", "CarClinchDB")

CONTAINERS = [
    { "id": "dealerships",   "pk": "/id" },
    { "id": "vehicles",      "pk": "/dealerId" },
    { "id": "leads",         "pk": "/id" },
    { "id": "conversations", "pk": "/leadId" },
    { "id": "messages",      "pk": "/conversationId" }
]

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

CASCADE_DELETE_CONVERSATION = """
function cascadeDeleteConversation(conversationId) {
    var collection = getContext().getCollection();
    var response = getContext().getResponse();
    var query = {
        query: "SELECT * FROM c WHERE c.conversationId = @cid",
        parameters: [{ name: "@cid", value: conversationId }]
    };
    var docs = [];
    var accepted = collection.queryDocuments(collection.getSelfLink(), query, function (err, feed) {
        if (err) throw err;
        docs = feed;
        deleteDocs();
    });
    if (!accepted) throw new Error("Query not accepted");
    function deleteDocs() {
        if (docs.length === 0) { response.setBody("Cascade delete complete"); return; }
        var doc = docs.pop();
        var accepted = collection.deleteDocument(doc._self, function (err) {
            if (err) throw err;
            deleteDocs();
        });
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
    var accepted = collection.queryDocuments(collection.getSelfLink(), query, function (err, feed) {
        if (err) throw err;
        docs = feed;
        deleteDocs();
    });
    if (!accepted) throw new Error("Query not accepted");
    function deleteDocs() {
        if (docs.length === 0) { response.setBody("Cascade delete complete"); return; }
        var doc = docs.pop();
        var accepted = collection.deleteDocument(doc._self, function (err) {
            if (err) throw err;
            deleteDocs();
        });
        if (!accepted) throw new Error("Delete not accepted");
    }
}
"""

def main():
    print(f"Connecting to Cosmos DB at {ENDPOINT}...")
    client = CosmosClient(ENDPOINT, KEY)

    print(f"Ensuring database '{DB_NAME}' exists...")
    db = client.create_database_if_not_exists(id=DB_NAME)

    for c in CONTAINERS:
        print(f"  Container '{c['id']}' (pk={c['pk']})...")
        container = db.create_container_if_not_exists(
            id=c["id"],
            partition_key=PartitionKey(path=c["pk"])
        )

        if c["id"] == "messages":
            try:
                container.scripts.delete_stored_procedure("cascadeDeleteConversation")
            except exceptions.CosmosResourceNotFoundError:
                pass
            print("  Uploading cascadeDeleteConversation stored procedure...")
            container.scripts.create_stored_procedure({
                "id": "cascadeDeleteConversation",
                "body": CASCADE_DELETE_CONVERSATION
            })

        if c["id"] == "conversations":
            try:
                container.scripts.delete_stored_procedure("cascadeDeleteLead")
            except exceptions.CosmosResourceNotFoundError:
                pass
            print("  Uploading cascadeDeleteLead stored procedure...")
            container.scripts.create_stored_procedure({
                "id": "cascadeDeleteLead",
                "body": CASCADE_DELETE_LEAD
            })

    print("Seeding dealerships...")
    dealerships = db.get_container_client("dealerships")
    for d in DEALERSHIPS:
        dealerships.upsert_item(d)

    print("Seeding vehicles...")
    vehicles = db.get_container_client("vehicles")
    for v in VEHICLES:
        vehicles.upsert_item(v)

    print("Seed complete.")

if __name__ == "__main__":
    main()
