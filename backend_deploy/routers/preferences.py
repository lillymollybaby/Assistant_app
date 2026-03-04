"""
User preferences router — syncs iOS UserDefaults to server.
"""
import logging
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel
from typing import Any

from database import get_db
from models import User
from routers.auth import get_current_user

logger = logging.getLogger("aura.preferences")

router = APIRouter(prefix="/preferences", tags=["preferences"])


class PreferencesResponse(BaseModel):
    preferences: dict[str, Any]


class PreferencesUpdate(BaseModel):
    preferences: dict[str, Any]


@router.get("", response_model=PreferencesResponse)
async def get_preferences(
    current_user: User = Depends(get_current_user),
):
    """Get all user preferences."""
    return PreferencesResponse(preferences=current_user.preferences or {})


@router.put("", response_model=PreferencesResponse)
async def replace_preferences(
    data: PreferencesUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Replace all preferences (full sync from device)."""
    current_user.preferences = data.preferences
    await db.flush()
    logger.info(f"Preferences replaced for user {current_user.id}")
    return PreferencesResponse(preferences=current_user.preferences)


@router.patch("", response_model=PreferencesResponse)
async def update_preferences(
    data: PreferencesUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Merge/update preferences (partial update)."""
    existing = current_user.preferences or {}
    existing.update(data.preferences)
    current_user.preferences = existing
    await db.flush()
    logger.info(f"Preferences updated for user {current_user.id}")
    return PreferencesResponse(preferences=current_user.preferences)
