# Quick Reference Guide: PostgreSQL + Docker + CLI

## 1. Start PostgreSQL using Docker Compose

### Start the database 
```bash
docker compose up -d
```

### View logs 
```bash
docker logs -f followup_db
```

### Stop the database 
```bash
docker compose down -v
```

### Reset the database (important when schema changes) 
```bash
docker compose down -v
docker compose up -d
```

---

# 2. Access PostgreSQL inside the container 

### Enter the container 
```bash
docker exec -it followup_db bash
```

### Start the Postgres CLI 
```bash
psql -U postgres -d followupdb
```

Now you’ll see a prompt like:

```
followupdb=#
```

This means you're inside PostgreSQL.

---

# 3. Common PostgreSQL CLI Commands 

## List tables 
```sql
\dt
```

## Describe a table 
```sql
\d leads
```

## List all schemas 
```sql
\dn
```

## List all databases 
```sql
\l
```

## Show connection info 
```sql
\conninfo
```

---

# 4. Exiting 

### Exit psql 
```sql
\q
```

### Exit container 
```bash
exit
```
