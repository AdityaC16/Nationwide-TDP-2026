# Infrastructure

`sql/schema.sql` contains the SQL Server-compatible DDL for the carbon advisor
schema. The SQLAlchemy 2.0 models live in `src/api/models.py`; use
`src.api.db` to create an engine and obtain sessions.

For Azure, store the complete SQLAlchemy URL in an Azure Key Vault secret.
Configure `AZURE_KEY_VAULT_URL` and `AZURE_DATABASE_SECRET_NAME`; the
application uses `DefaultAzureCredential` so managed identity, Azure CLI
login, and other supported credential sources work without storing keys in
the repository. The URL should use the `mssql+pyodbc` dialect and include the
ODBC driver query parameter, for example:

`mssql+pyodbc://user:password@server.database.windows.net/database?driver=ODBC+Driver+18+for+SQL+Server`

For local development and tests only, `DATABASE_URL` overrides Key Vault.
Never commit that value or any Azure credentials.
