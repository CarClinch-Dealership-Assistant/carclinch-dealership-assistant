from azure.cosmos import CosmosClient
import urllib3

# since cosmos db emulator uses self-signed cert, we'll disable warnings for local development (not recommended for production code)
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# cosmos db emulator defaults, not sensitive since it's local development only
ENDPOINT = "https://localhost:8081"
KEY = "C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw==" 

DB_NAME = "CarClinchDB"

LEADS = "leads"
CONVERSATIONS = "conversations"
MESSAGES = "messages"
VEHICLES = "vehicles"
DEALERSHIPS = "dealerships"


def print_header(title):
    print("\n" + "-" * 80)
    print(title)
    print("-" * 80)


def get_container(db, name):
    return db.get_container_client(name)


def show_lead_to_conversations(db, lead_id):
    print_header(f"Lead -> Conversations <- Vehicle (lead_id = {lead_id})")

    print(
        "Conversations serve two roles in the data schema:\n"
        "1. They act as a join table between leads and vehicles (many-many)\n"
        "   Each conversation links a lead to a specific vehicle the customer is\n"
        "   interested in (via vehicleId).\n"
        "2. They act as the conversation feed, similar to a ChatGPT log, where all\n"
        "   messages, emails, and interactions for that lead/vehicle pair are grouped.\n"
    )

    conversations = list(
        get_container(db, CONVERSATIONS).query_items(
            query="SELECT * FROM c WHERE c.leadId = @lid",
            parameters=[{"name": "@lid", "value": lead_id}],
            enable_cross_partition_query=True
        )
    )

    if not conversations:
        print("No conversations found.")
        return []

    for c in conversations:
        print(f"- Conversation {c['id']} (vehicleId={c.get('vehicleId')})")

    return conversations


def show_conversation_to_messages(db, conversation_id):
    print_header(f"Conversation -> Messages (conversation_id = {conversation_id})")

    print(
        "Messages belong to a conversation via conversationId. This includes inbound\n"
        "emails and outbound emails. The conversation acts as the parent container \n"
        "for the entire communication history.\n"
    )

    messages = list(
        get_container(db, MESSAGES).query_items(
            query="SELECT * FROM c WHERE c.conversationId = @cid",
            parameters=[{"name": "@cid", "value": conversation_id}],
            enable_cross_partition_query=True
        )
    )

    if not messages:
        print("No messages found.")
        return []

    for m in messages:
        print(f"- Message {m['id']} | source={m['source']} | emailMessageIdRef={m.get('emailMessageIdRef')}")

    return messages


def show_vehicle_to_dealership(db, vehicle_id):
    print_header(f"Vehicle -> Dealership (vehicle_id = {vehicle_id})")

    print(
        "Each vehicle belongs to a dealership, represented by dealerId.\n"
    )

    vehicles = list(
        get_container(db, VEHICLES).query_items(
            query="SELECT * FROM c WHERE c.id = @vid",
            parameters=[{"name": "@vid", "value": vehicle_id}],
            enable_cross_partition_query=True
        )
    )

    if not vehicles:
        print("Vehicle not found.")
        return

    vehicle = vehicles[0]
    dealer_id = vehicle["dealerId"]

    print(f"Vehicle {vehicle_id}: {vehicle['year']} {vehicle['make']} {vehicle['model']} (dealerId={dealer_id})")

    dealerships = list(
        get_container(db, DEALERSHIPS).query_items(
            query="SELECT * FROM c WHERE c.id = @did",
            parameters=[{"name": "@did", "value": dealer_id}],
            enable_cross_partition_query=True
        )
    )

    if dealerships:
        dealer = dealerships[0]
        print(f"-> Dealership: {dealer['address1']}, {dealer['city']} {dealer['province']}")
    else:
        print("-> Dealership not found.")


def show_email_threading(messages):
    print_header("Email Threading Demonstration")

    print(
        "Email threading in CarClinch works through two fields:\n"
        "1. emailMessageIdRef: this stores the message-id of the outbound email we sent.\n"
        "   When a customer replies, their email client includes this message-id in the\n"
        "   'in-reply-to' header, allowing us to match the inbound email to the correct\n"
        "   outbound message.\n"
        "2. emailThreadId: this is the ACS thread identifier. All outbound emails for\n"
        "   the same conversation must reuse this thread-id so ACS groups them into the\n"
        "   same email thread.\n"
    )

    if not messages:
        print("No messages to analyze.")
        return

    messages = sorted(messages, key=lambda m: m.get("timestamp", ""))

    print("Message pairs (outbound -> inbound):\n")

    last_outbound = None

    for m in messages:
        source = m.get("source")
        msg_id = m["id"]
        msg_body = m.get("body")
        msg_ref = m.get("emailMessageIdRef")
        thread_id = m.get("emailThreadId")

        if source == 0:
            # Outbound/system message
            print(f"OUTBOUND (system) message:")
            print(f"  id: {msg_id}")
            print(f"  body: {msg_body}")
            print(f"  emailMessageIdRef: {msg_ref}")
            print(f"  emailThreadId:     {thread_id}")
            last_outbound = m
            print("")  # blank line for readability

        elif source == 1:
            # Inbound/lead reply
            print(f"INBOUND (lead) reply:")
            print(f"  id: {msg_id}")
            print(f"  body: {msg_body}")
            print(f"  emailMessageIdRef: {msg_ref}")
            print(f"  emailThreadId:     {thread_id}")

            # If this inbound message corresponds to the last outbound, add spacing
            if last_outbound:
                print("\n--- End of outbound/inbound pair ---\n")
                last_outbound = None

        else:
            # Unknown source
            print(f"UNKNOWN message type for {msg_id}")
            print("")



def main():
    client = CosmosClient(ENDPOINT, KEY)
    db = client.get_database_client(DB_NAME)

    print_header("Cosmos DB Relationship Demo")

    # pick a lead to demonstrate relationships
    lead_id = input("Enter a leadId to explore (ex. lead_229fub8ss0): ").strip()

    conversations = show_lead_to_conversations(db, lead_id)

    if not conversations:
        print("\nNo conversations found for this lead. Done.")
        return

    for convo in conversations:
        convo_id = convo["id"]
        vehicle_id = convo.get("vehicleId")

        messages = show_conversation_to_messages(db, convo_id)

        show_email_threading(messages)

        if vehicle_id:
            show_vehicle_to_dealership(db, vehicle_id)
        else:
            print("Conversation has no vehicleId.")


if __name__ == "__main__":
    main()
