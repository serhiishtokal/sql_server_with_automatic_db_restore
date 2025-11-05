# SQL Server in Docker with Automatic Database Restore

This project provides a Docker Compose setup for running SQL Server 2022 with automatic database restoration from a backup file.

## Prerequisites

- Docker Desktop installed and running
- A SQL Server backup file (.bak)
- Windows, macOS, or Linux operating system

## Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/serhiishtokal/sql_server_with_automatic_db_restore.git
   cd sql_server_with_automatic_db_restore/SQL_SERVER
   ```

2. **Configure environment variables**
   
   Copy the example environment file and update it with your settings:
   ```bash
   cp .env_example .env
   ```

3. **Edit the `.env` file** with your specific configuration:
   ```env
   # SQL Server settings
   SQL_CONTAINER_NAME=sqlserver2022
   MSSQL_SA_PASSWORD=YourStrongPassword123!
   MSSQL_PID=Developer
   SQL_PORT=1433

   # Backup settings
   BACKUP_FILE=your_database.bak
   LOCAL_BACKUP_DIR=C:/path/to/your/backup/folder

   # Database name to restore
   DATABASE_NAME=YourDatabaseName
   ```

   **Important**: 
   - `MSSQL_SA_PASSWORD` must be a strong password (at least 8 characters, including uppercase, lowercase, numbers, and symbols)
   - `LOCAL_BACKUP_DIR` should point to the folder containing your `.bak` file
   - `BACKUP_FILE` is the name of your backup file
   - `DATABASE_NAME` is the name you want for your restored database

4. **Place your backup file**
   
   Ensure your `.bak` file is in the directory specified by `LOCAL_BACKUP_DIR`

5. **Start the services**
   ```bash
   docker compose up -d
   ```

## What Happens When You Run It

1. SQL Server 2022 container starts and waits until it's healthy
2. The `db_restore` service automatically restores your database from the backup file
3. SQL Server is accessible on `localhost:1433` (or your configured port)

## Connecting to SQL Server

You can connect to the SQL Server instance using:

- **Server**: `localhost,1433` (or your configured port)
- **Username**: `sa`
- **Password**: The value you set in `MSSQL_SA_PASSWORD`
- **Database**: The value you set in `DATABASE_NAME`

### Using SQL Server Management Studio (SSMS)
1. Open SSMS
2. Server name: `localhost,1433`
3. Authentication: SQL Server Authentication
4. Login: `sa`
5. Password: Your configured password

### Using Azure Data Studio
1. Open Azure Data Studio
2. New Connection
3. Server: `localhost,1433`
4. Authentication type: SQL Login
5. User name: `sa`
6. Password: Your configured password

## Checking Restore Status

To check if the database restore was successful:

```bash
docker compose logs db_restore
```

You should see a message saying "Restore complete" if successful.

## Managing the Services

**Stop the services:**
```bash
docker compose down
```

**Stop and remove volumes (WARNING: This will delete all data):**
```bash
docker compose down -v
```

**View logs:**
```bash
docker compose logs -f sqlserver
```

**Restart services:**
```bash
docker compose restart
```

## Troubleshooting

### Database restore fails

1. Check that your backup file path is correct:
   ```bash
   docker compose exec sqlserver ls -la /var/opt/mssql/backup
   ```

2. Check the restore logs:
   ```bash
   docker compose logs db_restore
   ```

3. Verify the logical file names in your backup match the RESTORE command in `compose.yml`. You may need to update the `MOVE` clauses if your backup has different logical names.

### Cannot connect to SQL Server

1. Verify the container is running:
   ```bash
   docker compose ps
   ```

2. Check if SQL Server is healthy:
   ```bash
   docker compose exec sqlserver /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P YourPassword -Q "SELECT @@VERSION"
   ```

3. Ensure no other service is using port 1433 on your host machine

### Password doesn't meet requirements

If you see an error about password requirements, ensure your `MSSQL_SA_PASSWORD` includes:
- At least 8 characters
- Uppercase letters
- Lowercase letters
- Numbers
- Special characters

## Project Structure

```
.
├── .env                  # Your local configuration (not in git)
├── .env_example          # Example configuration file
├── compose.yml           # Docker Compose configuration
├── .gitignore           # Git ignore rules
└── README.md            # This file
```

## Environment Variables Reference

| Variable | Description | Example |
|----------|-------------|---------|
| `SQL_CONTAINER_NAME` | Name of the SQL Server container | `sqlserver2022` |
| `MSSQL_SA_PASSWORD` | SA user password (must be strong) | `HardPassw0rd!` |
| `MSSQL_PID` | SQL Server edition (Developer, Express, Standard, Enterprise) | `Developer` |
| `SQL_PORT` | Port to expose SQL Server on host | `1433` |
| `BACKUP_FILE` | Name of the backup file | `database.bak` |
| `LOCAL_BACKUP_DIR` | Local directory containing backup file | `C:/path/to/backups` |
| `DATABASE_NAME` | Name for the restored database | `MyDatabase` |

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
