from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    DATABASE_URL: str = "postgresql+asyncpg://user:password@localhost:5432/aura"

    # JWT
    SECRET_KEY: str = "your-secret-key-change-this-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 дней

    # Gemini
    GEMINI_API_KEY: str = ""

    # 2GIS
    TWOGIS_API_KEY: str = ""

    # TMDB
    TMDB_API_KEY: str = ""

    # AWS S3
    AWS_ACCESS_KEY_ID: str = ""
    AWS_SECRET_ACCESS_KEY: str = ""
    AWS_REGION: str = "us-east-1"
    S3_BUCKET_NAME: str = "aura-food-photos"

    # SMTP (for email verification & password reset)
    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    FROM_EMAIL: str = ""
    FROM_NAME: str = "AURA App"

    # App URLs
    APP_NAME: str = "AURA"
    FRONTEND_URL: str = "https://aura-api.ddns.net"

    class Config:
        env_file = ".env"


settings = Settings()
