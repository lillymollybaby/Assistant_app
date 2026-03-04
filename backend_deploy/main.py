import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

from database import engine, Base
from routers import auth

logger = logging.getLogger("aura")

# ─── Rate Limiter ───
limiter = Limiter(key_func=get_remote_address, default_limits=["60/minute"])


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    logger.info("Database connected, tables ready")
    yield
    await engine.dispose()
    logger.info("Database connection closed")


app = FastAPI(
    title="AURA API",
    description="Backend for AURA app",
    version="1.3.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url=None,
)

# Rate limiting
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS — iOS apps don't need CORS, restrict to our domain only
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://aura-api.ddns.net"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PATCH", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled error on {request.url}: {exc}", exc_info=True)
    return JSONResponse(status_code=500, content={"detail": "Internal server error"})

# Routers
app.include_router(auth.router)
from routers import food, logistics, cinema, languages, fridge, recipes, shopping, preferences
app.include_router(food.router)
app.include_router(logistics.router)
app.include_router(cinema.router)
app.include_router(languages.router)
app.include_router(fridge.router)
app.include_router(recipes.router)
app.include_router(shopping.router)
app.include_router(preferences.router)


@app.get("/")
async def root():
    return {"status": "ok", "message": "AURA API v1.3"}


@app.get("/health")
async def health():
    return {"status": "healthy"}
