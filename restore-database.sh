#!/bin/bash

echo '=== Starting Database Restore Process ==='
echo "Database: ${DATABASE_NAME}"
echo "Backup file: ${BACKUP_FILE}"
echo ''

BACKUP_PATH="/var/opt/mssql/backup/${BACKUP_FILE}"

echo 'Step 1: Checking if backup file exists...'
if [ ! -f "$BACKUP_PATH" ]; then
  echo "ERROR: Backup file not found at $BACKUP_PATH"
  echo 'Please verify:'
  echo '  1. LOCAL_BACKUP_DIR is correct in .env file'
  echo '  2. BACKUP_FILE name matches the actual file'
  echo '  3. The backup file exists in the specified directory'
  ls -lah /var/opt/mssql/backup/ || echo 'Cannot list backup directory'
  exit 1
fi
echo 'SUCCESS: Backup file found'
echo "File size: $(du -h "$BACKUP_PATH" | cut -f1)"
echo ''

echo 'Step 2: Testing SQL Server connection...'
/opt/mssql-tools/bin/sqlcmd -S sqlserver -U sa -P "${MSSQL_SA_PASSWORD}" -d master -Q "SELECT @@VERSION" -h -1 > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo 'ERROR: Cannot connect to SQL Server'
  echo 'Please verify MSSQL_SA_PASSWORD is correct'
  exit 1
fi
echo 'SUCCESS: Connected to SQL Server'
echo ''

echo "Step 3: Getting backup file information..."
# Get count of backup sets in the file - we want the last one
BACKUP_POSITION=$(/opt/mssql-tools/bin/sqlcmd -S sqlserver -U sa -P "${MSSQL_SA_PASSWORD}" -d master -Q "SET NOCOUNT ON; RESTORE HEADERONLY FROM DISK = '/var/opt/mssql/backup/${BACKUP_FILE}'" -h -1 2>&1 | grep -c "^")

if [ -z "$BACKUP_POSITION" ] || [ "$BACKUP_POSITION" -le 0 ]; then
  echo "Could not detect backup sets, defaulting to position 1"
  BACKUP_POSITION=1
fi

echo "Total backup sets in file: $BACKUP_POSITION"
echo "Using backup at position: $BACKUP_POSITION (latest)"

# Get logical file names from the specified position
FILELIST=$(/opt/mssql-tools/bin/sqlcmd -S sqlserver -U sa -P "${MSSQL_SA_PASSWORD}" -d master -Q "RESTORE FILELISTONLY FROM DISK = '/var/opt/mssql/backup/${BACKUP_FILE}' WITH FILE = ${BACKUP_POSITION}" -h -1 -W -s "," 2>&1)
if [ $? -ne 0 ]; then
  echo 'ERROR: Failed to read backup file'
  echo "$FILELIST"
  exit 1
fi

# Extract logical file names (first column of each row)
DATA_FILE=$(echo "$FILELIST" | grep -v "rows affected" | head -1 | cut -d',' -f1 | tr -d ' ')
LOG_FILE=$(echo "$FILELIST" | grep -v "rows affected" | head -2 | tail -1 | cut -d',' -f1 | tr -d ' ')

echo "Detected data file: $DATA_FILE"
echo "Detected log file: $LOG_FILE"
echo ''

echo "Step 4: Checking if database exists and dropping it..."
DB_EXISTS=$(/opt/mssql-tools/bin/sqlcmd -S sqlserver -U sa -P "${MSSQL_SA_PASSWORD}" -d master -Q "SELECT COUNT(*) FROM sys.databases WHERE name = '${DATABASE_NAME}'" -h -1 -W 2>&1 | tr -d ' ')
if [ "$DB_EXISTS" -gt 0 ]; then
  echo "Database exists, setting to single user mode and dropping..."
  /opt/mssql-tools/bin/sqlcmd -S sqlserver -U sa -P "${MSSQL_SA_PASSWORD}" -d master -Q "ALTER DATABASE [${DATABASE_NAME}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [${DATABASE_NAME}];" 2>&1
  if [ $? -eq 0 ]; then
    echo "SUCCESS: Existing database dropped"
  else
    echo "WARNING: Failed to drop existing database, will try REPLACE"
  fi
else
  echo "No existing database found"
fi
echo ''

echo "Step 5: Restoring database [${DATABASE_NAME}] from backup..."
set -x
/opt/mssql-tools/bin/sqlcmd -S sqlserver -U sa -P "${MSSQL_SA_PASSWORD}" -d master -Q "RESTORE DATABASE [${DATABASE_NAME}] FROM DISK = '/var/opt/mssql/backup/${BACKUP_FILE}' WITH FILE = ${BACKUP_POSITION}, MOVE '${DATA_FILE}' TO '/var/opt/mssql/data/${DATABASE_NAME}.mdf', MOVE '${LOG_FILE}' TO '/var/opt/mssql/data/${DATABASE_NAME}_log.ldf', REPLACE, RECOVERY" 2>&1
exitcode=$?
set +x
echo ''

if [ $exitcode -eq 0 ]; then
  echo "Step 6: Verifying database is online..."
  DB_STATE=$(/opt/mssql-tools/bin/sqlcmd -S sqlserver -U sa -P "${MSSQL_SA_PASSWORD}" -d master -Q "SELECT state_desc FROM sys.databases WHERE name = '${DATABASE_NAME}'" -h -1 -W 2>&1)
  echo "Database state: $DB_STATE"
  
  echo ''
  echo "Step 7: Checking table count and row counts..."
  /opt/mssql-tools/bin/sqlcmd -S sqlserver -U sa -P "${MSSQL_SA_PASSWORD}" -d "${DATABASE_NAME}" -Q "SELECT COUNT(*) AS TableCount FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE'" -h -1 2>&1 | head -5
  echo ''
  echo "Sample table row counts (first 5 tables):"
  /opt/mssql-tools/bin/sqlcmd -S sqlserver -U sa -P "${MSSQL_SA_PASSWORD}" -d "${DATABASE_NAME}" -Q "SELECT TOP 5 t.name AS TableName, SUM(p.rows) AS RowCount FROM sys.tables t INNER JOIN sys.partitions p ON t.object_id = p.object_id WHERE p.index_id IN (0,1) GROUP BY t.name ORDER BY t.name" -W 2>&1 | head -10
  
  echo ''
  echo '=== SUCCESS: Database restore completed successfully ==='
  echo "Database [${DATABASE_NAME}] is now ready to use"
  exit 0
else
  echo "=== ERROR: Database restore failed with exit code $exitcode ==="
  echo 'Common issues:'
  echo '  1. Backup file is corrupted'
  echo '  2. Insufficient disk space'
  echo '  3. SQL Server version mismatch'
  echo '  4. Permissions issues'
  exit $exitcode
fi
