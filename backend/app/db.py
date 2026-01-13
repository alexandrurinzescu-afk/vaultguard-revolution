import sqlite3
from pathlib import Path


DB_PATH = Path(__file__).resolve().parents[1] / "vaultguard.db"


def get_conn() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    with get_conn() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS user_entitlements (
              user_id TEXT PRIMARY KEY,
              tier TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS identity_verifications (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id TEXT NOT NULL,
              vendor TEXT NOT NULL,
              status TEXT NOT NULL,
              verification_date TEXT NOT NULL,
              token_hash TEXT NOT NULL
            )
            """
        )
        conn.commit()

