---
name: docker-compose-exec
description: Run commands inside Docker Compose services. Use when services are only reachable from inside compose networks.
---

## When to Use

- Accessing services only available within Docker Compose network (databases, APIs, etc.)
- Running CLI tools that exist only inside a compose service container
- Debugging compose service networking or internal state
- Executing migrations, seeds, or admin commands in compose services

## Workflow

### 1. Identify the Target Service

First, determine which service to use:

```bash
docker compose ps
```

Look for:
- A running service with the required tools/access
- The service name from `docker-compose.yml`

### 2. Choose Execution Method

**If service is already running** → Use `docker compose exec`
**If service is not running** → Use `docker compose run --rm`

### 3. Execute the Command

#### Option A: Running Service (docker compose exec)

```bash
docker compose exec <service_name> <command>
```

For interactive commands, add `-it` (or omit if compose defaults are fine):
```bash
docker compose exec -it <service_name> <command>
```

Examples:
```bash
# Run psql in a running postgres service
docker compose exec db psql -U myuser -d mydb

# Run a Rails migration
docker compose exec web rails db:migrate

# Check connectivity from inside service
docker compose exec web curl -s http://internal-service:3000/health
```

#### Option B: No Running Service (docker compose run --rm)

```bash
docker compose run --rm <service_name> <command>
```

Examples:
```bash
# Run psql against a database in the compose network
docker compose run --rm db psql -U myuser -d mydb

# Run a one-off script with volumes and env set by compose
docker compose run --rm app python /app/script.py
```

### 4. Compose Project Context

Run commands from the directory with `docker-compose.yml` or specify:

```bash
docker compose -f /path/to/docker-compose.yml ps
```

## Common Patterns

### Database Access

```bash
# PostgreSQL - running service
docker compose exec db psql -U postgres -d mydb -c "SELECT * FROM users LIMIT 5;"

# PostgreSQL - no running service
docker compose run --rm db psql -U postgres -d mydb

# MySQL - running service
docker compose exec mysql mysql -u root -p mydb

# Redis - running service
docker compose exec redis redis-cli KEYS '*'
```

### Running Migrations/Seeds

```bash
# Rails
docker compose exec web rails db:migrate
docker compose exec web rails db:seed

# Django
docker compose exec web python manage.py migrate
docker compose exec web python manage.py loaddata fixtures.json

# Node.js (Prisma)
docker compose exec web npx prisma migrate deploy
```

### Debugging Network Issues

```bash
# Check DNS resolution inside service
docker compose exec web nslookup service_name

# Test connectivity to internal service
docker compose exec web curl -v http://internal-api:8080/health

# Check what ports are listening
docker compose exec web netstat -tlnp
```

### Interactive Shell

```bash
# Get a shell in running service
docker compose exec web /bin/sh
docker compose exec web /bin/bash

# Get a shell in fresh service container
docker compose run --rm web /bin/sh
```

## Flags Reference

| Flag | Purpose |
|------|---------|
| `-it` | Interactive terminal (use for shells, psql, etc.) |
| `--rm` | Remove container after exit (for docker compose run) |
| `-e VAR=value` | Set environment variable (run only) |
| `-v host:container` | Mount volume (run only) |
| `-w /path` | Set working directory |
| `--user uid:gid` | Run as specific user |

## Troubleshooting

**"Service not found"**: Check service name with `docker compose ps`

**"Compose file not found"**: Run from directory containing `docker-compose.yml` or pass `-f`

**"Command not found"**: The tool may not be installed in that service. Try a different service or add it to the image.

**Permission denied**: Try adding `--user root` or check volume mount permissions
