CREATE SCHEMA IF NOT EXISTS dealership;
ALTER DATABASE followupdb SET search_path TO dealership, public;

CREATE TABLE IF NOT EXISTS dealerships (
    dealer_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email          TEXT,
    phone          VARCHAR(30),
    address1       TEXT,
    address2       TEXT,
    city           TEXT,
    province       TEXT,
    postal_code    VARCHAR(7)
);

CREATE TABLE IF NOT EXISTS vehicles (
    vehicle_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dealer_id      INT NOT NULL REFERENCES dealerships(dealer_id) ON DELETE RESTRICT,
    stock_id       VARCHAR(20),
    status         INT,        -- 0 = new, 1 = used
    year           INT,
    vin            VARCHAR(17),
    make           TEXT,
    model          TEXT,
    trim           VARCHAR(30),
    mileage        VARCHAR(10),
    transmission   VARCHAR(15),
    comments       TEXT
);

CREATE TABLE IF NOT EXISTS leads (
    lead_id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fname          TEXT,
    lname          TEXT,
    email          TEXT,
    phone          VARCHAR(30),
    status         INT,        -- 0 = new, 1 = contacted, 2 = test drive, 3 = won, 4 = lost
    vehicle_id     INT REFERENCES vehicles(vehicle_id) ON DELETE SET NULL,
    wants_email    BOOLEAN,
    notes          TEXT,
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS conversations (
    conversation_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    lead_id         INT NOT NULL REFERENCES leads(lead_id) ON DELETE CASCADE,
    status          INT,        -- 0 = inactive, 1 = active
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    last_updated    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS conv_lead_idx     ON conversations(lead_id);
CREATE INDEX IF NOT EXISTS conv_status_idx   ON conversations(status);
CREATE INDEX IF NOT EXISTS conv_updated_idx  ON conversations(last_updated DESC);

CREATE TABLE IF NOT EXISTS messages (
    message_id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    conversation_id    INT NOT NULL REFERENCES conversations(conversation_id) ON DELETE CASCADE,
    body               TEXT,
    source             INT,               -- 0 = outbound/CarClinch, 1 = inbound/Lead
    in_reply_to        TEXT,
    email_thread       TEXT,
    message_identifier TEXT,
    created_at         TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS msg_conv_idx   ON messages(conversation_id, created_at);
CREATE INDEX IF NOT EXISTS msg_source_idx ON messages(source);
CREATE INDEX IF NOT EXISTS msg_msgid_idx  ON messages(message_identifier);

-- TRIGGER: bump conversations.last_updated on new message
CREATE OR REPLACE FUNCTION bump_conversation_last_updated()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE conversations
    SET last_updated = NEW.created_at
    WHERE conversation_id = NEW.conversation_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_messages_bump_conversation ON messages;

CREATE TRIGGER trg_messages_bump_conversation
AFTER INSERT ON messages
FOR EACH ROW
EXECUTE FUNCTION bump_conversation_last_updated();
