from sqlalchemy import (
    String, Integer, Float, Boolean, DateTime, Text,
    ForeignKey, JSON, Enum as SAEnum
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from datetime import datetime
from database import Base
import enum


# ─────────────────────────────────────────
# ENUMS
# ─────────────────────────────────────────

class LanguageLevel(str, enum.Enum):
    A1 = "A1"
    A2 = "A2"
    B1 = "B1"
    B2 = "B2"
    C1 = "C1"
    C2 = "C2"


class MealType(str, enum.Enum):
    breakfast = "breakfast"
    lunch = "lunch"
    dinner = "dinner"
    snack = "snack"


class FridgeCategory(str, enum.Enum):
    meat = "meat"
    dairy = "dairy"
    vegetables = "vegetables"
    fruits = "fruits"
    grains = "grains"
    other = "other"


# ─────────────────────────────────────────
# USERS
# ─────────────────────────────────────────

class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    username: Mapped[str] = mapped_column(String(100), unique=True, index=True, nullable=False)
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)
    full_name: Mapped[str | None] = mapped_column(String(200))
    avatar_url: Mapped[str | None] = mapped_column(String(500))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now(), onupdate=func.now())

    # Email verification
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    verification_code: Mapped[str | None] = mapped_column(String(6))
    verification_code_expires: Mapped[datetime | None] = mapped_column(DateTime)

    # Password reset
    reset_token: Mapped[str | None] = mapped_column(String(100))
    reset_token_expires: Mapped[datetime | None] = mapped_column(DateTime)

    # User preferences (synced from iOS)
    preferences: Mapped[dict | None] = mapped_column(JSON)

    # Настройки пользователя
    calorie_goal: Mapped[int] = mapped_column(Integer, default=2200)
    protein_goal: Mapped[int] = mapped_column(Integer, default=150)
    carbs_goal: Mapped[int] = mapped_column(Integer, default=250)
    fat_goal: Mapped[int] = mapped_column(Integer, default=70)
    step_goal: Mapped[int] = mapped_column(Integer, default=10000)

    # Связи
    meals: Mapped[list["Meal"]] = relationship("Meal", back_populates="user", cascade="all, delete")
    routes: Mapped[list["Route"]] = relationship("Route", back_populates="user", cascade="all, delete")
    language_progress: Mapped[list["LanguageProgress"]] = relationship("LanguageProgress", back_populates="user", cascade="all, delete")
    watched_movies: Mapped[list["WatchedMovie"]] = relationship("WatchedMovie", back_populates="user", cascade="all, delete")
    vocab_cards: Mapped[list["VocabCard"]] = relationship("VocabCard", back_populates="user", cascade="all, delete")
    fridge_items: Mapped[list["FridgeItem"]] = relationship("FridgeItem", back_populates="user", cascade="all, delete")
    recipes: Mapped[list["UserRecipe"]] = relationship("UserRecipe", back_populates="user", cascade="all, delete")
    shopping_items: Mapped[list["ShoppingItem"]] = relationship("ShoppingItem", back_populates="user", cascade="all, delete")
    meal_plans: Mapped[list["MealPlan"]] = relationship("MealPlan", back_populates="user", cascade="all, delete")


# ─────────────────────────────────────────
# TOKEN BLACKLIST (for logout)
# ─────────────────────────────────────────

class TokenBlacklist(Base):
    __tablename__ = "token_blacklist"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    token: Mapped[str] = mapped_column(String(500), unique=True, index=True, nullable=False)
    blacklisted_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    expires_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)


# ─────────────────────────────────────────
# FOOD
# ─────────────────────────────────────────

class Meal(Base):
    __tablename__ = "meals"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    meal_type: Mapped[MealType] = mapped_column(SAEnum(MealType), nullable=False)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    photo_url: Mapped[str | None] = mapped_column(String(500))

    # КБЖУ — Gemini считает по фото
    calories: Mapped[float] = mapped_column(Float, default=0)
    protein: Mapped[float] = mapped_column(Float, default=0)
    carbs: Mapped[float] = mapped_column(Float, default=0)
    fat: Mapped[float] = mapped_column(Float, default=0)

    # Gemini анализ
    ai_tip: Mapped[str | None] = mapped_column(Text)
    ingredients: Mapped[dict | None] = mapped_column(JSON)

    eaten_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    user: Mapped["User"] = relationship("User", back_populates="meals")


# ─────────────────────────────────────────
# LOGISTICS
# ─────────────────────────────────────────

class Route(Base):
    __tablename__ = "routes"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    address: Mapped[str] = mapped_column(String(500), nullable=False)
    lat: Mapped[float | None] = mapped_column(Float)
    lon: Mapped[float | None] = mapped_column(Float)
    scheduled_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    drive_time_minutes: Mapped[int] = mapped_column(Integer, default=0)
    distance_km: Mapped[float] = mapped_column(Float, default=0)
    is_completed: Mapped[bool] = mapped_column(Boolean, default=False)
    notes: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    user: Mapped["User"] = relationship("User", back_populates="routes")


# ─────────────────────────────────────────
# LANGUAGES
# ─────────────────────────────────────────

class LanguageProgress(Base):
    __tablename__ = "language_progress"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    language_code: Mapped[str] = mapped_column(String(10), nullable=False)
    language_name: Mapped[str] = mapped_column(String(50), nullable=False)
    level: Mapped[LanguageLevel] = mapped_column(SAEnum(LanguageLevel), default=LanguageLevel.A1)
    streak_days: Mapped[int] = mapped_column(Integer, default=0)
    total_minutes: Mapped[int] = mapped_column(Integer, default=0)
    last_study_date: Mapped[datetime | None] = mapped_column(DateTime)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    user: Mapped["User"] = relationship("User", back_populates="language_progress")


class VocabCard(Base):
    __tablename__ = "vocab_cards"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    language_code: Mapped[str] = mapped_column(String(10), nullable=False)
    word: Mapped[str] = mapped_column(String(200), nullable=False)
    translation: Mapped[str] = mapped_column(String(200), nullable=False)
    definition: Mapped[str | None] = mapped_column(Text)
    example_sentence: Mapped[str | None] = mapped_column(Text)
    source: Mapped[str | None] = mapped_column(String(50))
    source_ref: Mapped[str | None] = mapped_column(String(200))
    is_bookmarked: Mapped[bool] = mapped_column(Boolean, default=False)

    # Spaced Repetition
    times_reviewed: Mapped[int] = mapped_column(Integer, default=0)
    times_correct: Mapped[int] = mapped_column(Integer, default=0)
    next_review_at: Mapped[datetime | None] = mapped_column(DateTime)

    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    user: Mapped["User"] = relationship("User", back_populates="vocab_cards")


# ─────────────────────────────────────────
# CINEMA
# ─────────────────────────────────────────

class WatchedMovie(Base):
    __tablename__ = "watched_movies"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    tmdb_id: Mapped[int] = mapped_column(Integer, nullable=False)
    title: Mapped[str] = mapped_column(String(300), nullable=False)
    original_title: Mapped[str | None] = mapped_column(String(300))
    poster_url: Mapped[str | None] = mapped_column(String(500))
    director: Mapped[str | None] = mapped_column(String(200))
    year: Mapped[int | None] = mapped_column(Integer)
    rating: Mapped[float | None] = mapped_column(Float)
    user_rating: Mapped[float | None] = mapped_column(Float)
    genres: Mapped[list | None] = mapped_column(JSON)
    watched_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    watched: Mapped[bool] = mapped_column(Boolean, default=False)
    review: Mapped[str | None] = mapped_column(Text)

    vocab_extracted: Mapped[bool] = mapped_column(Boolean, default=False)

    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    user: Mapped["User"] = relationship("User", back_populates="watched_movies")


# ─────────────────────────────────────────
# FRIDGE
# ─────────────────────────────────────────

class FridgeItem(Base):
    __tablename__ = "fridge_items"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    quantity: Mapped[str] = mapped_column(String(100), nullable=False)
    category: Mapped[FridgeCategory] = mapped_column(SAEnum(FridgeCategory), default=FridgeCategory.other)
    emoji: Mapped[str | None] = mapped_column(String(10))
    barcode: Mapped[str | None] = mapped_column(String(100))
    expiry_date: Mapped[datetime | None] = mapped_column(DateTime)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    user: Mapped["User"] = relationship("User", back_populates="fridge_items")


# ─────────────────────────────────────────
# RECIPES
# ─────────────────────────────────────────

class UserRecipe(Base):
    __tablename__ = "user_recipes"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    name: Mapped[str] = mapped_column(String(300), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    ingredients: Mapped[dict | None] = mapped_column(JSON)
    calories: Mapped[int] = mapped_column(Integer, default=0)
    proteins: Mapped[float] = mapped_column(Float, default=0)
    fats: Mapped[float] = mapped_column(Float, default=0)
    carbs: Mapped[float] = mapped_column(Float, default=0)
    cook_time: Mapped[int] = mapped_column(Integer, default=0)
    category: Mapped[str | None] = mapped_column(String(50))
    cuisine: Mapped[str | None] = mapped_column(String(100))
    image_url: Mapped[str | None] = mapped_column(String(500))
    is_saved: Mapped[bool] = mapped_column(Boolean, default=True)
    source: Mapped[str | None] = mapped_column(String(50))
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    user: Mapped["User"] = relationship("User", back_populates="recipes")


# ─────────────────────────────────────────
# SHOPPING LIST
# ─────────────────────────────────────────

class ShoppingItem(Base):
    __tablename__ = "shopping_items"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    amount: Mapped[str | None] = mapped_column(String(100))
    category: Mapped[str | None] = mapped_column(String(50))
    is_checked: Mapped[bool] = mapped_column(Boolean, default=False)
    from_recipe: Mapped[str | None] = mapped_column(String(300))
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    user: Mapped["User"] = relationship("User", back_populates="shopping_items")


# ─────────────────────────────────────────
# MEAL PLAN
# ─────────────────────────────────────────

class MealPlan(Base):
    __tablename__ = "meal_plans"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    recipe_id: Mapped[int | None] = mapped_column(Integer, ForeignKey("user_recipes.id"))
    date: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    meal_type: Mapped[MealType] = mapped_column(SAEnum(MealType), nullable=False)
    recipe_name: Mapped[str | None] = mapped_column(String(300))
    notes: Mapped[str | None] = mapped_column(Text)
    is_completed: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    user: Mapped["User"] = relationship("User", back_populates="meal_plans")
    recipe: Mapped["UserRecipe"] = relationship("UserRecipe")
