# Personal Carbon Footprint & Savings Advisor

Nationwide TDP 2026 Capstone Project.

## Local setup

Create a local environment file and install dependencies:

```powershell
Copy-Item .env.example .env
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
```

By default, local development uses SQLite at `carbon_advisor.db`. Run the
database migration with:

```powershell
python -m src.api.migrate
```

Set `DATABASE_URL` in `.env` to override SQLite for tests or another local
database. For Azure, set `CLOUD_STORAGE_ENABLED=1` and configure the Azure Key
Vault variables described in `.env.example`.
