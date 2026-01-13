from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_entitlements_defaults_to_lite():
    r = client.get("/api/user/entitlements", params={"userId": "u123"})
    assert r.status_code == 200
    data = r.json()
    assert data["tier"] == "LITE"
    assert "demo_onboarding" in data["features"]


def test_mock_purchase_upgrades_tier():
    r = client.post("/api/mock/purchase", json={"userId": "u123", "tier": "ANGEL"})
    assert r.status_code == 200
    data = r.json()
    assert data["tier"] == "ANGEL"
    assert "real_biometric_auth" in data["features"]

    r2 = client.get("/api/user/entitlements", params={"userId": "u123"})
    assert r2.json()["tier"] == "ANGEL"


def test_verify_identity_stub_ok():
    r = client.post("/api/verify-identity", json={"userId": "u123", "vendor": "ONFIDO", "token": "mock"})
    assert r.status_code == 200
    assert r.json()["status"] == "VERIFIED"

