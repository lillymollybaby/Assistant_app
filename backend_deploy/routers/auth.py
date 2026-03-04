import logging
import uuid
from fastapi import APIRouter, Depends, HTTPException, status, Request
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from passlib.context import CryptContext
from jose import JWTError, jwt
from datetime import datetime, timedelta, timezone
from pydantic import BaseModel, EmailStr
from slowapi import Limiter
from slowapi.util import get_remote_address

from database import get_db
from models import User, TokenBlacklist
from config import settings
from utils.email import (
    generate_verification_code,
    generate_reset_token,
    send_verification_email,
    send_password_reset_email,
)

logger = logging.getLogger("aura.auth")

router = APIRouter(prefix="/auth", tags=["auth"])

# Rate limiter for auth endpoints (stricter)
limiter = Limiter(key_func=get_remote_address)

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# OAuth2
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")


# ─── Schemas ───

class UserRegister(BaseModel):
    email: EmailStr
    username: str
    password: str
    full_name: str | None = None


class UserResponse(BaseModel):
    id: int
    email: str
    username: str
    full_name: str | None
    avatar_url: str | None
    is_verified: bool
    calorie_goal: int
    protein_goal: int
    carbs_goal: int
    fat_goal: int
    step_goal: int
    created_at: datetime

    class Config:
        from_attributes = True


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse


class UpdateProfile(BaseModel):
    full_name: str | None = None
    calorie_goal: int | None = None
    protein_goal: int | None = None
    carbs_goal: int | None = None
    fat_goal: int | None = None
    step_goal: int | None = None


class VerifyEmailRequest(BaseModel):
    email: EmailStr
    code: str


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    email: EmailStr
    code: str
    new_password: str


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str


class ResendVerificationRequest(BaseModel):
    email: EmailStr


class MessageResponse(BaseModel):
    message: str


# ─── Utilities ───

def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


def create_access_token(user_id: int) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {"sub": str(user_id), "exp": expire, "jti": uuid.uuid4().hex}
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


async def is_token_blacklisted(token: str, db: AsyncSession) -> bool:
    """Check if a token has been blacklisted (logged out)."""
    result = await db.execute(
        select(TokenBlacklist).where(TokenBlacklist.token == token)
    )
    return result.scalar_one_or_none() is not None


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db)
) -> User:
    """Dependency — get current user from JWT token."""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid token",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    # Check blacklist
    if await is_token_blacklisted(token, db):
        raise credentials_exception

    result = await db.execute(select(User).where(User.id == int(user_id)))
    user = result.scalar_one_or_none()

    if user is None or not user.is_active:
        raise credentials_exception

    return user


# ─── Auth Endpoints ───

@router.post("/register", response_model=TokenResponse, status_code=201)
@limiter.limit("5/minute")
async def register(request: Request, data: UserRegister, db: AsyncSession = Depends(get_db)):
    """Register a new user. Sends verification email."""
    # Validate password length
    if len(data.password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters")

    # Check email and username availability
    existing = await db.execute(
        select(User).where(
            (User.email == data.email) | (User.username == data.username)
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=400,
            detail="User with this email or username already exists"
        )

    # Generate verification code
    code = generate_verification_code()

    user = User(
        email=data.email,
        username=data.username,
        hashed_password=hash_password(data.password),
        full_name=data.full_name,
        is_verified=False,
        verification_code=code,
        verification_code_expires=datetime.utcnow() + timedelta(minutes=15),
    )
    db.add(user)
    await db.flush()

    # Send verification email (non-blocking — don't fail registration if email fails)
    send_verification_email(data.email, code, data.full_name or "")

    token = create_access_token(user.id)
    logger.info(f"New user registered: {data.username}")

    return TokenResponse(
        access_token=token,
        user=UserResponse.model_validate(user)
    )


@router.post("/login", response_model=TokenResponse)
@limiter.limit("10/minute")
async def login(
    request: Request,
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db)
):
    """Login — accepts email or username."""
    result = await db.execute(
        select(User).where(
            (User.email == form_data.username) | (User.username == form_data.username)
        )
    )
    user = result.scalar_one_or_none()

    if not user or not verify_password(form_data.password, user.hashed_password):
        logger.warning(f"Failed login attempt for: {form_data.username}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email/username or password"
        )

    if not user.is_active:
        raise HTTPException(status_code=400, detail="Account is blocked")

    token = create_access_token(user.id)
    return TokenResponse(
        access_token=token,
        user=UserResponse.model_validate(user)
    )


@router.post("/logout", response_model=MessageResponse)
async def logout(
    token: str = Depends(oauth2_scheme),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Logout — blacklist current token."""
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        exp = datetime.utcfromtimestamp(payload["exp"])
    except JWTError:
        exp = datetime.utcnow() + timedelta(days=7)

    blacklisted = TokenBlacklist(token=token, expires_at=exp)
    db.add(blacklisted)
    logger.info(f"User {current_user.id} logged out")
    return MessageResponse(message="Successfully logged out")


# ─── Email Verification ───

@router.post("/verify-email", response_model=MessageResponse)
@limiter.limit("10/minute")
async def verify_email(request: Request, data: VerifyEmailRequest, db: AsyncSession = Depends(get_db)):
    """Verify email with 6-digit code."""
    result = await db.execute(select(User).where(User.email == data.email))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if user.is_verified:
        return MessageResponse(message="Email already verified")

    if not user.verification_code or user.verification_code != data.code:
        raise HTTPException(status_code=400, detail="Invalid verification code")

    if user.verification_code_expires and user.verification_code_expires < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Verification code has expired")

    user.is_verified = True
    user.verification_code = None
    user.verification_code_expires = None
    logger.info(f"Email verified for user {user.id}")

    return MessageResponse(message="Email verified successfully")


@router.post("/resend-verification", response_model=MessageResponse)
@limiter.limit("3/minute")
async def resend_verification(request: Request, data: ResendVerificationRequest, db: AsyncSession = Depends(get_db)):
    """Resend verification code."""
    result = await db.execute(select(User).where(User.email == data.email))
    user = result.scalar_one_or_none()

    if not user:
        # Don't reveal whether user exists
        return MessageResponse(message="If this email is registered, a new code has been sent")

    if user.is_verified:
        return MessageResponse(message="Email already verified")

    code = generate_verification_code()
    user.verification_code = code
    user.verification_code_expires = datetime.utcnow() + timedelta(minutes=15)

    send_verification_email(user.email, code, user.full_name or "")

    return MessageResponse(message="If this email is registered, a new code has been sent")


# ─── Password Reset ───

@router.post("/forgot-password", response_model=MessageResponse)
@limiter.limit("3/minute")
async def forgot_password(request: Request, data: ForgotPasswordRequest, db: AsyncSession = Depends(get_db)):
    """Request password reset — sends code to email."""
    result = await db.execute(select(User).where(User.email == data.email))
    user = result.scalar_one_or_none()

    # Always return success (don't reveal if email exists)
    if not user:
        return MessageResponse(message="If this email is registered, a reset code has been sent")

    code = generate_verification_code()
    user.reset_token = code
    user.reset_token_expires = datetime.utcnow() + timedelta(minutes=15)

    send_password_reset_email(user.email, code, user.full_name or "")

    return MessageResponse(message="If this email is registered, a reset code has been sent")


@router.post("/reset-password", response_model=MessageResponse)
@limiter.limit("5/minute")
async def reset_password(request: Request, data: ResetPasswordRequest, db: AsyncSession = Depends(get_db)):
    """Reset password with code from email."""
    if len(data.new_password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters")

    result = await db.execute(select(User).where(User.email == data.email))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=400, detail="Invalid reset code")

    if not user.reset_token or user.reset_token != data.code:
        raise HTTPException(status_code=400, detail="Invalid reset code")

    if user.reset_token_expires and user.reset_token_expires < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Reset code has expired")

    user.hashed_password = hash_password(data.new_password)
    user.reset_token = None
    user.reset_token_expires = None
    logger.info(f"Password reset for user {user.id}")

    return MessageResponse(message="Password reset successfully")


# ─── Password Change (authenticated) ───

@router.post("/change-password", response_model=MessageResponse)
async def change_password(
    data: ChangePasswordRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Change password for authenticated user."""
    if not verify_password(data.current_password, current_user.hashed_password):
        raise HTTPException(status_code=400, detail="Current password is incorrect")

    if len(data.new_password) < 6:
        raise HTTPException(status_code=400, detail="New password must be at least 6 characters")

    current_user.hashed_password = hash_password(data.new_password)
    logger.info(f"Password changed for user {current_user.id}")

    return MessageResponse(message="Password changed successfully")


# ─── Profile ───

@router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    """Get current user data."""
    return current_user


@router.patch("/me", response_model=UserResponse)
async def update_profile(
    data: UpdateProfile,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Update profile."""
    for field, value in data.model_dump(exclude_none=True).items():
        setattr(current_user, field, value)
    await db.flush()
    return current_user


# ─── Account Deletion (GDPR) ───

@router.delete("/me", response_model=MessageResponse)
async def delete_account(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Delete user account and all associated data. Irreversible."""
    user_id = current_user.id
    logger.warning(f"Deleting account for user {user_id} ({current_user.email})")

    # cascade="all, delete" on relationships handles child records
    await db.delete(current_user)
    await db.flush()

    logger.info(f"Account deleted: user {user_id}")
    return MessageResponse(message="Account deleted successfully")


# ─── Cleanup expired blacklist tokens (call periodically) ───

async def cleanup_expired_tokens(db: AsyncSession):
    """Remove expired tokens from blacklist to keep table small."""
    await db.execute(
        delete(TokenBlacklist).where(
            TokenBlacklist.expires_at < datetime.utcnow()
        )
    )
    await db.commit()
