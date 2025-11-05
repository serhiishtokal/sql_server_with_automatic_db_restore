# SQL Server in Docker with Automatic Database Restore

Docker Compose setup for SQL Server 2022 with automatic database restoration from a backup file.

## Prerequisites

- Docker Desktop
- SQL Server backup file (.bak)

## Quick Start

1. **Clone and configure**
   ```bash
   git clone https://github.com/serhiishtokal/sql_server_with_automatic_db_restore.git
   cd sql_server_with_automatic_db_restore
   cp .env_example .env
   ```

2. **Edit `.env` file**
   ```env
   MSSQL_SA_PASSWORD=YourStrongPassword123!
   BACKUP_FILE=your_database.bak
   LOCAL_BACKUP_DIR=C:/path/to/your/backup/folder
   DATABASE_NAME=YourDatabaseName
   ```

3. **Start**
   ```bash
   docker compose up -d
   ```

## Connection Details

Use the connection details based on your `.env` configuration:

- **Server**: `localhost,<SQL_PORT>` (use the `SQL_PORT` value from your `.env` file)
- **User**: `sa`
- **Password**: Use the `MSSQL_SA_PASSWORD` value from your `.env` file
- **Database**: Use the `DATABASE_NAME` value from your `.env` file

## Useful Commands

```bash
# Check restore status
docker compose logs db_restore

# Stop services
docker compose down

# View SQL Server logs
docker compose logs -f sqlserver
```

## Troubleshooting

Check logs for detailed error messages:
```bash
docker compose logs db_restore
```

Common issues:
- **Backup file not found**: Verify `LOCAL_BACKUP_DIR` and `BACKUP_FILE` in `.env`
- **Connection failed**: Check `MSSQL_SA_PASSWORD` (needs 8+ chars with uppercase, lowercase, numbers, symbols)
- **Restore fails**: Check logs for specific error messages

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MSSQL_SA_PASSWORD` | SA password (must be strong) | Required |
| `BACKUP_FILE` | Backup filename | Required |
| `LOCAL_BACKUP_DIR` | Backup folder path | Required |
| `DATABASE_NAME` | Restored database name | Required |
| `SQL_PORT` | SQL Server port | `1433` |

## License

MIT License
