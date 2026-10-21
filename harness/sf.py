"""Shared Snowflake helpers. SSO via externalbrowser with a cached token."""
import os
from pathlib import Path

import snowflake.connector

ROOT = Path(__file__).resolve().parent.parent


def load_config() -> dict:
    cfg = {}
    for line in (ROOT / "config.env").read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            cfg[k.strip()] = v.strip()
    cfg.update({k: v for k, v in os.environ.items() if k in cfg})
    return cfg


CFG = load_config()


def connect(schema: str | None = None):
    return snowflake.connector.connect(
        account=CFG["SF_ACCOUNT"],
        user=CFG["SF_USER"],
        role=CFG["SF_ROLE"],
        warehouse=CFG["SF_WAREHOUSE"],
        database=CFG["SF_DATABASE"],
        schema=schema,
        authenticator="externalbrowser",
        client_store_temporary_credential=True,
    )


def run(conn, sql: str, params=None):
    cur = conn.cursor()
    try:
        cur.execute(sql, params)
        try:
            return cur.fetchall()
        except snowflake.connector.errors.ProgrammingError:
            return []
    finally:
        cur.close()


def run_many(conn, statements: list[str]):
    for s in statements:
        if s.strip():
            run(conn, s)


def run_schemas(run_id: str) -> dict:
    rid = run_id.upper().replace("-", "_")
    return {
        "raw": f"F1_RAW_{rid}",  # what the agent sources from
        "truth": f"ZZ_F1EVAL_TRUTH_{rid}",  # legit data changes only; answer keys read this
        "target": f"F1_DBT_{rid}",  # agent's dbt target schema
    }
