"""Database engine and session helpers."""

import os
from collections.abc import Generator

from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from .models import Base

load_dotenv()

DATABASE_URL_ENV = "DATABASE_URL"
CLOUD_STORAGE_ENABLED_ENV = "CLOUD_STORAGE_ENABLED"
KEY_VAULT_URL_ENV = "AZURE_KEY_VAULT_URL"
DATABASE_SECRET_NAME_ENV = "AZURE_DATABASE_SECRET_NAME"
LOCAL_DATABASE_URL = "sqlite:///./carbon_advisor.db"


def get_database_url() -> str:
    """Load the database URL from local configuration or Azure Key Vault."""
    database_url = os.getenv(DATABASE_URL_ENV)
    if database_url:
        return database_url

    if os.getenv(CLOUD_STORAGE_ENABLED_ENV, "0").lower() not in {"1", "true", "yes"}:
        return LOCAL_DATABASE_URL

    key_vault_url = os.getenv(KEY_VAULT_URL_ENV)
    secret_name = os.getenv(DATABASE_SECRET_NAME_ENV)
    if not key_vault_url or not secret_name:
        raise RuntimeError(
            f"Set {DATABASE_URL_ENV} for local use, or set both "
            f"{KEY_VAULT_URL_ENV} and {DATABASE_SECRET_NAME_ENV}."
        )

    credential = DefaultAzureCredential()
    client = SecretClient(vault_url=key_vault_url, credential=credential)
    secret = client.get_secret(secret_name)
    if not secret.value:
        raise RuntimeError(f"Azure Key Vault secret '{secret_name}' has no value.")
    return secret.value


DATABASE_URL = get_database_url()
engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False}
    if DATABASE_URL.startswith("sqlite")
    else {},
)
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


def get_db() -> Generator[Session, None, None]:
    """Yield a database session and close it after use."""
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()


def init_db() -> None:
    """Create all mapped tables in the configured database."""
    Base.metadata.create_all(bind=engine)
