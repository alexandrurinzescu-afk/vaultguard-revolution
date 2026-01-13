from datetime import datetime, timezone
from enum import Enum
from pydantic import BaseModel, Field


class UserTier(str, Enum):
    LITE = "LITE"
    ANGEL = "ANGEL"
    REVOLUTION = "REVOLUTION"


class EntitlementsResponse(BaseModel):
    userId: str
    tier: UserTier
    features: list[str]
    issuedAt: str


class PurchaseRequest(BaseModel):
    userId: str = Field(min_length=3)
    tier: UserTier


class VerifyIdentityRequest(BaseModel):
    userId: str = Field(min_length=3)
    vendor: str = Field(min_length=2)
    token: str = Field(min_length=1)


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def features_for_tier(tier: UserTier) -> list[str]:
    if tier == UserTier.LITE:
        return ["demo_onboarding", "demo_scan"]
    if tier == UserTier.ANGEL:
        return ["demo_onboarding", "real_biometric_auth", "real_biometric_enrollment", "id_verification"]
    return [
        "demo_onboarding",
        "real_biometric_auth",
        "real_biometric_enrollment",
        "id_verification",
        "premium_revolution",
    ]

