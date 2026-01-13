from hashlib import sha256

from fastapi import FastAPI, HTTPException

from .db import get_conn, init_db
from .models import (
    EntitlementsResponse,
    PurchaseRequest,
    UserTier,
    VerifyIdentityRequest,
    features_for_tier,
    now_iso,
)


app = FastAPI(title="VaultGuard Backend (Stub)", version="0.1.2")


@app.on_event("startup")
def _startup() -> None:
    init_db()


def get_tier_for_user(user_id: str) -> UserTier:
    with get_conn() as conn:
        row = conn.execute(
            "SELECT tier FROM user_entitlements WHERE user_id = ?",
            (user_id,),
        ).fetchone()
        if not row:
            return UserTier.LITE
        return UserTier(row["tier"])


def set_tier_for_user(user_id: str, tier: UserTier) -> None:
    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO user_entitlements(user_id, tier, updated_at)
            VALUES(?, ?, ?)
            ON CONFLICT(user_id) DO UPDATE SET tier=excluded.tier, updated_at=excluded.updated_at
            """,
            (user_id, tier.value, now_iso()),
        )
        conn.commit()


@app.get("/api/user/entitlements", response_model=EntitlementsResponse)
def get_entitlements(userId: str) -> EntitlementsResponse:
    if not userId or len(userId) < 3:
        raise HTTPException(status_code=400, detail="userId is required")
    tier = get_tier_for_user(userId)
    return EntitlementsResponse(
        userId=userId,
        tier=tier,
        features=features_for_tier(tier),
        issuedAt=now_iso(),
    )


@app.post("/api/mock/purchase", response_model=EntitlementsResponse)
def mock_purchase(req: PurchaseRequest) -> EntitlementsResponse:
    # This endpoint is ONLY for development/testing.
    set_tier_for_user(req.userId, req.tier)
    tier = get_tier_for_user(req.userId)
    return EntitlementsResponse(
        userId=req.userId,
        tier=tier,
        features=features_for_tier(tier),
        issuedAt=now_iso(),
    )


@app.post("/api/verify-identity")
def verify_identity(req: VerifyIdentityRequest) -> dict:
    # Stub: accept any token and mark verified.
    token_hash = sha256(req.token.encode("utf-8")).hexdigest()
    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO identity_verifications(user_id, vendor, status, verification_date, token_hash)
            VALUES(?, ?, ?, ?, ?)
            """,
            (req.userId, req.vendor, "VERIFIED", now_iso(), token_hash),
        )
        conn.commit()
    return {"ok": True, "status": "VERIFIED"}

