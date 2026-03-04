#!/usr/bin/env python3
"""
Migration script to add new columns to users table and create token_blacklist table.
Run once after deploying models.py v1.3.
"""
import asyncio
import sys
sys.path.insert(0, '/home/ubuntu/aura-backend')

from sqlalchemy import text
from database import engine

async def migrate():
    async with engine.begin() as conn:
        print("Starting migration...")

        # Add new columns to users table
        columns_to_add = [
            ("is_verified", "BOOLEAN DEFAULT FALSE"),
            ("verification_code", "VARCHAR(6)"),
            ("verification_code_expires", "TIMESTAMP"),
            ("reset_token", "VARCHAR(100)"),
            ("reset_token_expires", "TIMESTAMP"),
            ("preferences", "JSON"),
        ]

        for col_name, col_type in columns_to_add:
            try:
                await conn.execute(text(f"ALTER TABLE users ADD COLUMN {col_name} {col_type}"))
                print(f"  Added column: users.{col_name}")
            except Exception as e:
                if "already exists" in str(e).lower() or "duplicate" in str(e).lower():
                    print(f"  Column users.{col_name} already exists, skipping")
                else:
                    print(f"  Error adding users.{col_name}: {e}")

        # Create token_blacklist table
        try:
            await conn.execute(text("""
                CREATE TABLE IF NOT EXISTS token_blacklist (
                    id SERIAL PRIMARY KEY,
                    token VARCHAR(500) UNIQUE NOT NULL,
                    blacklisted_at TIMESTAMP DEFAULT NOW(),
                    expires_at TIMESTAMP NOT NULL
                )
            """))
            await conn.execute(text("CREATE INDEX IF NOT EXISTS ix_token_blacklist_token ON token_blacklist(token)"))
            print("  Created table: token_blacklist")
        except Exception as e:
            print(f"  Error with token_blacklist: {e}")

        # Update existing users to have is_verified = false where null
        await conn.execute(text("UPDATE users SET is_verified = FALSE WHERE is_verified IS NULL"))
        print("  Set is_verified=FALSE for existing users")

        print("Migration complete!")

asyncio.run(migrate())
