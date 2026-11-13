"""Create the database schema and load the seed data.

Usage: python -m src.api.migrate [--reset]
"""

import argparse
import sqlite3
from collections.abc import Iterator
from pathlib import Path

from .db import engine, init_db
from .models import Base

SEED_SCRIPT = Path(__file__).resolve().parents[2] / "infra" / "sql" / "seed.sql"


def split_statements(script: str) -> Iterator[str]:
    """Split a SQL script into statements, respecting quotes and comments."""
    statement = ""
    for line in script.splitlines(keepends=True):
        statement += line
        if sqlite3.complete_statement(statement):
            yield statement.strip()
            statement = ""
    if statement.strip() and not all(
        part.strip().startswith("--") or not part.strip()
        for part in statement.splitlines()
    ):
        raise ValueError(f"Unterminated SQL statement in seed script:\n{statement}")


def apply_seed_script() -> None:
    """Run seed.sql in a single transaction (works on SQLite and SQL Server)."""
    statements = list(split_statements(SEED_SCRIPT.read_text(encoding="utf-8")))
    is_mssql = engine.dialect.name == "mssql"

    with engine.begin() as connection:
        if is_mssql:
            # The seed inserts explicit CustomerIds that match the appendix.
            connection.exec_driver_sql("SET IDENTITY_INSERT Customer ON")
        for statement in statements:
            connection.exec_driver_sql(statement)
        if is_mssql:
            connection.exec_driver_sql("SET IDENTITY_INSERT Customer OFF")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--reset",
        action="store_true",
        help="Drop and recreate all tables first. Needed after model column "
        "changes, because create_all never alters existing tables.",
    )
    if parser.parse_args().reset:
        Base.metadata.drop_all(bind=engine)
    init_db()
    apply_seed_script()
    print("Database schema and seed data are ready.")


if __name__ == "__main__":
    main()
