import argparse
from azure.cosmos import CosmosClient
import urllib3

# since cosmos db emulator uses self-signed cert, we'll disable warnings for local development (not recommended for production code)
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# cosmos db emulator defaults, not sensitive since it's local development only
ENDPOINT = "https://localhost:8081"
KEY = "C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw==" 

DB_NAME = "CarClinchDB"

# container names
CONVERSATIONS_CONTAINER = "conversations"
MESSAGES_CONTAINER = "messages"
LEADS_CONTAINER = "leads"

# function to run cascade delete for a conversation, which should also delete related messages
def run_cascade_delete_conversation(client, conversation_id):
    db = client.get_database_client(DB_NAME)

    messages_container = db.get_container_client(MESSAGES_CONTAINER)
    conversations_container = db.get_container_client(CONVERSATIONS_CONTAINER)

    print(f"Running cascadeDeleteConversation for: {conversation_id}")

    # first we execute the stored procedure to delete the messages related to the conversation
    result = messages_container.scripts.execute_stored_procedure(
        sproc="cascadeDeleteConversation",
        params=[conversation_id],
        partition_key=conversation_id
    )

    print("Message deletion result:", result)

    # then we fetch the conversation to get its leadId (partition key)
    query = "SELECT * FROM c WHERE c.id = @id"
    params = [{"name": "@id", "value": conversation_id}]

    items = list(conversations_container.query_items(
        query=query,
        parameters=params,
        enable_cross_partition_query=True
    ))

    if not items:
        print("Conversation not found — nothing to delete.")
        return

    conversation = items[0]
    lead_id = conversation["leadId"]

    print(f"Deleting conversation {conversation_id} with partition key {lead_id}")

    # then we also delete the conversation item itself from the conversations container
    conversations_container.delete_item(
        item=conversation_id,
        partition_key=lead_id
    )

    print("Conversation deleted successfully.")

# function to run cascade delete for a lead, which should also delete related conversations and messages
def run_cascade_delete_lead(client, lead_id):
    db = client.get_database_client(DB_NAME)

    conversations_container = db.get_container_client(CONVERSATIONS_CONTAINER)
    messages_container = db.get_container_client(MESSAGES_CONTAINER)
    leads_container = db.get_container_client(LEADS_CONTAINER)

    print(f"Running full cascade delete for lead: {lead_id}")

    # first get all conversations for this lead
    conversations = list(conversations_container.query_items(
        query="SELECT * FROM c WHERE c.leadId = @lid",
        parameters=[{"name": "@lid", "value": lead_id}],
        enable_cross_partition_query=True
    ))

    print(f"Found {len(conversations)} conversations for lead {lead_id}")

    # then for each conversation, delete its messages
    for convo in conversations:
        convo_id = convo["id"]
        print(f"Deleting messages for conversation {convo_id}")

        messages_container.scripts.execute_stored_procedure(
            sproc="cascadeDeleteConversation",
            params=[convo_id],
            partition_key=convo_id
        )

    # first delete all conversations using the stored procedure
    print("Deleting conversations...")
    conversations_container.scripts.execute_stored_procedure(
        sproc="cascadeDeleteLead",
        params=[lead_id],
        partition_key=lead_id
    )

    # then delete the lead document itself
    print("Deleting lead document...")
    leads_container.delete_item(
        item=lead_id,
        partition_key=lead_id
    )

    print("Lead cascade delete complete.")



# main function to parse command line arguments and run the appropriate cascade delete test
def main():
    parser = argparse.ArgumentParser(
        description="Test Cosmos DB cascade delete stored procedures."
    )

    parser.add_argument(
        "--conversation",
        type=str,
        help="Conversation ID to cascade delete"
    )

    parser.add_argument(
        "--lead",
        type=str,
        help="Lead ID to cascade delete"
    )

    args = parser.parse_args()

    if not args.conversation and not args.lead:
        print("Error: You must specify either --conversation or --lead")
        return

    client = CosmosClient(ENDPOINT, KEY)

    if args.conversation:
        run_cascade_delete_conversation(client, args.conversation)

    if args.lead:
        run_cascade_delete_lead(client, args.lead)


if __name__ == "__main__":
    main()
