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
        "id": "dealer_123",
        "email": "dealer@example.com",
        "phone": "555-1234",
        "address1": "123 Main St",
        "address2": "",
        "city": "Ottawa",
        "province": "ON",
        "postal_code": "K1A0B1"
    },
    {
        "id": "dealer_456",
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
        "id": "vehicle_987",
        "dealerId": "dealer_123",
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
        "id": "vehicle_654",
        "dealerId": "dealer_123",
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
        "id": "vehicle_321",
        "dealerId": "dealer_456",
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

def main():
    print("Connecting to Cosmos DB Emulator...")
    client = CosmosClient(ENDPOINT, KEY)

    print(f"Ensuring database '{DB_NAME}' exists...")
    db = client.create_database_if_not_exists(id=DB_NAME)

    # create containers
    for c in CONTAINERS:
        print(f"Ensuring container '{c['id']}' exists with PK '{c['pk']}'...")
        db.create_container_if_not_exists(
            id=c["id"],
            partition_key=PartitionKey(path=c["pk"])
        )

    # seed dealerships
    dealerships_container = db.get_container_client("dealerships")
    for d in DEALERSHIPS:
        print(f"Upserting dealership {d['id']}...")
        dealerships_container.upsert_item(d)

    # seed vehicles
    vehicles_container = db.get_container_client("vehicles")
    for v in VEHICLES:
        print(f"Upserting vehicle {v['id']} for dealer {v['dealerId']}...")
        vehicles_container.upsert_item(v)

    print("Seeding complete.")

if __name__ == "__main__":
    main()
