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

echo "Step 3: Restoring database [${DATABASE_NAME}] from backup..."
set -x
/opt/mssql-tools/bin/sqlcmd -S sqlserver -U sa -P "${MSSQL_SA_PASSWORD}" -d master -Q "RESTORE DATABASE [${DATABASE_NAME}] FROM DISK = '/var/opt/mssql/backup/${BACKUP_FILE}' WITH MOVE 'MR_UMBRACO_R7' TO '/var/opt/mssql/data/${DATABASE_NAME}.mdf', MOVE 'MR_UMBRACO_R7_log' TO '/var/opt/mssql/data/${DATABASE_NAME}.ldf', REPLACE" 2>&1
exitcode=$?
set +x
echo ''

if [ $exitcode -eq 0 ]; then
  echo '=== SUCCESS: Database restore completed successfully ==='
  echo "Database [${DATABASE_NAME}] is now ready to use"
  exit 0
else
  echo "=== ERROR: Database restore failed with exit code $exitcode ==="
  echo 'Common issues:'
  echo '  1. Logical file names in backup do not match (MR_UMBRACO_R7, MR_UMBRACO_R7_log)'
  echo '  2. Backup file is corrupted'
  echo '  3. Insufficient disk space'
  echo '  4. SQL Server version mismatch'
  echo ''
  echo 'To check logical file names in your backup, run:'
  echo "  docker compose run --rm db_restore /opt/mssql-tools/bin/sqlcmd -S sqlserver -U sa -P \${MSSQL_SA_PASSWORD} -Q \"RESTORE FILELISTONLY FROM DISK = '/var/opt/mssql/backup/${BACKUP_FILE}'\""
  exit $exitcode
fi
