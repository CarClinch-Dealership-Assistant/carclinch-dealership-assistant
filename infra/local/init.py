from azure.cosmos import CosmosClient, PartitionKey
import urllib3
import os
from dotenv import load_dotenv
import requests
import socket
import uuid

# 1. SSL & Connection Setup
original_request = requests.Session.request
def patched_request(self, *args, **kwargs):
    kwargs['verify'] = False
    return original_request(self, *args, **kwargs)

requests.Session.request = patched_request
load_dotenv()
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# 2. Dynamic Host Detection
def get_host_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except:
        return "localhost"

HOST_IP = get_host_ip()
ENDPOINT = f"https://{HOST_IP}:8081/"
# Default Emulator Key
KEY = os.getenv("COSMOS_KEY", "C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw==") 
DB_NAME = "CarClinchDB"

# 3. Schema Definition
CONTAINERS = [
    { "id": "dealerships",   "pk": "/id" },
    { "id": "vehicles",      "pk": "/dealerId" },
    { "id": "leads",         "pk": "/email" },
    { "id": "conversations", "pk": "/leadId" },
    { "id": "messages",      "pk": "/conversationId" },
    { "id": "appointments",  "pk": "/dealerId" }
]

# 4. Seed Data
DEALERSHIPS = [
    {
        "id": "dealer_8c1d9f22aa",
        "name": "Example Dealership",
        "email": "carclinch-dev@outlook.com",
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
        "email": "carclinch-dev@outlook.com",
        "phone": "555-7777",
        "address1": "77 Carling Ave",
        "address2": "Unit 2",
        "city": "Ottawa",
        "province": "ON",
        "postal_code": "K2P1L4"
    },
    {
        "id": "dealer_9a3c12be55",
        "name": "Prestige Motors Montreal",
        "email": "carclinch-dev@outlook.com",
        "phone": "514-900-1111",
        "address1": "1200 Rue Peel",
        "address2": "Suite 100",
        "city": "Montreal",
        "province": "QC",
        "postal_code": "H3B2T6"
    },
    {
        "id": "dealer_2f7e44dc88",
        "name": "Northern Trucks Toronto",
        "email": "carclinch-dev@outlook.com",
        "phone": "416-555-3030",
        "address1": "890 Lake Shore Blvd W",
        "address2": "",
        "city": "Toronto",
        "province": "ON",
        "postal_code": "M6K3C3"
    }
]

VEHICLES = [
    # Economy / Daily Drivers
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
        "mileage": "45000 km",
        "transmission": "Automatic",
        "comments": "Clean car, no accidents"
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
        "mileage": "22000 km",
        "transmission": "Automatic",
        "comments": "Low mileage, one owner"
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
        "mileage": "0 km",
        "transmission": "Manual",
        "comments": "No previous owners, just serviced"
    },
    # Luxury Sedans
    {
        "id": "vehicle_5c1a77ff02",
        "dealerId": "dealer_9a3c12be55",
        "stock_id": "LUX001",
        "status": 1,
        "year": 2022,
        "vin": "WBAJB0C51JB123456",
        "make": "BMW",
        "model": "5 Series",
        "trim": "540i xDrive",
        "mileage": "31000 km",
        "transmission": "Automatic",
        "comments": "Full BMW warranty remaining, premium package, heads-up display"
    },
    {
        "id": "vehicle_8d2b44ee13",
        "dealerId": "dealer_9a3c12be55",
        "stock_id": "LUX002",
        "status": 1,
        "year": 2021,
        "vin": "WDDUF8CB4MA123789",
        "make": "Mercedes-Benz",
        "model": "E-Class",
        "trim": "E 450 4MATIC",
        "mileage": "28000 km",
        "transmission": "Automatic",
        "comments": "AMG Line exterior, panoramic roof, Burmester sound system"
    },
    # SUVs — Family & Utility
    {
        "id": "vehicle_6e9c02bb34",
        "dealerId": "dealer_4f92ab10c3",
        "stock_id": "SUV101",
        "status": 1,
        "year": 2020,
        "vin": "5TDDZRFH0LS123456",
        "make": "Toyota",
        "model": "Highlander",
        "trim": "XLE AWD",
        "mileage": "67000 km",
        "transmission": "Automatic",
        "comments": "3-row seating, tow package, clean carfax"
    },
    {
        "id": "vehicle_2a4f91cc57",
        "dealerId": "dealer_8c1d9f22aa",
        "stock_id": "SUV102",
        "status": 1,
        "year": 2023,
        "vin": "5XYZT3LB4PG123456",
        "make": "Kia",
        "model": "Telluride",
        "trim": "EX",
        "mileage": "14000 km",
        "transmission": "Automatic",
        "comments": "Nearly new, 8-passenger, heated seats, blind spot monitoring"
    },
    # Trucks
    {
        "id": "vehicle_9f3d88aa21",
        "dealerId": "dealer_2f7e44dc88",
        "stock_id": "TRK201",
        "status": 1,
        "year": 2021,
        "vin": "1FTFW1ET5MFA12345",
        "make": "Ford",
        "model": "F-150",
        "trim": "Lariat 4x4",
        "mileage": "55000 km",
        "transmission": "Automatic",
        "comments": "Max tow package, bed liner, remote start"
    },
    {
        "id": "vehicle_4b7c55dd90",
        "dealerId": "dealer_2f7e44dc88",
        "stock_id": "TRK202",
        "status": 1,
        "year": 2019,
        "vin": "3GCUKREC4KG123456",
        "make": "Chevrolet",
        "model": "Silverado 1500",
        "trim": "LT Trail Boss",
        "mileage": "89000 km",
        "transmission": "Automatic",
        "comments": "Off-road suspension lift, all-terrain tires, well maintained"
    },
    # EVs
    {
        "id": "vehicle_0e1f22bb78",
        "dealerId": "dealer_9a3c12be55",
        "stock_id": "EV301",
        "status": 1,
        "year": 2022,
        "vin": "5YJ3E1EA8NF123456",
        "make": "Tesla",
        "model": "Model 3",
        "trim": "Long Range AWD",
        "mileage": "38000 km",
        "transmission": "Automatic",
        "comments": "576 km range, autopilot, no accidents, includes home charger"
    },
    {
        "id": "vehicle_3c9a11ff45",
        "dealerId": "dealer_4f92ab10c3",
        "stock_id": "EV302",
        "status": 1,
        "year": 2023,
        "vin": "1C4JJXR68PW123456",
        "make": "Jeep",
        "model": "Wrangler",
        "trim": "4xe Rubicon",
        "mileage": "19000 km",
        "transmission": "Automatic",
        "comments": "Plug-in hybrid, 40 km EV range, removable doors and roof"
    },
    # Sports / Performance
    {
        "id": "vehicle_7a2e99cc63",
        "dealerId": "dealer_9a3c12be55",
        "stock_id": "SPT401",
        "status": 1,
        "year": 2020,
        "vin": "WP0AA2A99LS123456",
        "make": "Porsche",
        "model": "911",
        "trim": "Carrera S",
        "mileage": "21000 km",
        "transmission": "Automatic",
        "comments": "PDK transmission, sport chrono package, ceramic brakes"
    },
    {
        "id": "vehicle_1b8d44ee09",
        "dealerId": "dealer_4f92ab10c3",
        "stock_id": "SPT402",
        "status": 1,
        "year": 2021,
        "vin": "1FA6P8CF5M5123456",
        "make": "Ford",
        "model": "Mustang",
        "trim": "GT Premium",
        "mileage": "33000 km",
        "transmission": "Manual",
        "comments": "5.0L V8, Recaro seats, track-driven twice, no damage"
    }
]


def main():
    try:
        print(f"Connecting to Cosmos DB at {ENDPOINT}...")
        # connection_verify=False is the key for the emulator
        client = CosmosClient(ENDPOINT, KEY, connection_verify=False, request_timeout=60)

        print(f"Ensuring database '{DB_NAME}' exists...")
        db = client.create_database_if_not_exists(id=DB_NAME)

        # Create Containers
        for c in CONTAINERS:
            print(f"  Ensuring container '{c['id']}' (pk={c['pk']})...")
            db.create_container_if_not_exists(
                id=c["id"],
                partition_key=PartitionKey(path=c["pk"])
            )

        # Seeding Helper
        def seed_set(container_id, data_list):
            print(f"Seeding {container_id}...")
            container = db.get_container_client(container_id)
            for item in data_list:
                container.upsert_item(item)

        seed_set("dealerships", DEALERSHIPS)
        seed_set("vehicles", VEHICLES)

        print("\nSUCCESS: Database seeded successfully.")

    except Exception as e:
        print(f"\nERROR: Could not seed database.")
        print(f"Reason: {e}")
        print("\nTip: Ensure Docker is running and the Emulator has finished its 'Partitioning' phase.")

if __name__ == "__main__":
    main()