"""
VAULTGUARD SECURITY PARSER (SUBPUNCT 2.3.3)

Analyzes OCR-extracted text and detects security settings:
- Firewall
- Antivirus
- Windows Update
- Password policy
- Backup
- BitLocker / Drive encryption
- UAC

Usage:
  python security_parser.py --test
  python security_parser.py <file.txt>
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from datetime import datetime
from typing import Dict, List
import sys


@dataclass
class SettingResult:
    detected: bool
    status: str  # secure|insecure|neutral|unknown
    confidence: int  # 0..100
    evidence: List[str]


class SecuritySettingsParser:
    def __init__(self):
        self.rules = self._load_security_rules()

    def _load_security_rules(self) -> dict:
        # NOTE: MVP rules are keyword/pattern-based. Can be extended with locale dictionaries.
        return {
            "firewall": {
                "patterns": [
                    r"firewall\s*[:\-]?\s*(on|enabled|running|active|activ|activat|pornit)",
                    r"firewall\s*[:\-]?\s*(off|disabled|stopped|oprit|dezactivat|inactiv)",
                    r"(windows defender firewall|firewall).*(on|enabled|running|active|activ|activat|pornit)",
                    r"(windows defender firewall|firewall).*(off|disabled|stopped|oprit|dezactivat|inactiv)",
                ],
                "positive_keywords": ["on", "enabled", "running", "active", "activ", "activat", "pornit"],
                "negative_keywords": ["off", "disabled", "stopped", "oprit", "dezactivat", "inactiv"],
            },
            "antivirus": {
                "patterns": [
                    r"(antivirus|defender)\s*[:\-]?\s*(on|enabled|running|active|activ|activat|actualizat|up to date)",
                    r"(antivirus|defender)\s*[:\-]?\s*(off|disabled|stopped|oprit|dezactivat|outdated)",
                    r"(windows defender|defender antivirus|antivirus|virus.*protection).*(on|enabled|running|active|activ|activat|actualizat|up to date)",
                    r"(windows defender|defender antivirus|antivirus|virus.*protection).*(off|disabled|stopped|oprit|dezactivat|outdated)",
                ],
                "positive_keywords": ["on", "enabled", "running", "active", "activ", "activat", "actualizat", "up to date"],
                "negative_keywords": ["off", "disabled", "stopped", "oprit", "dezactivat", "outdated"],
            },
            "windows_update": {
                "patterns": [
                    r"(windows update|update)\s*[:\-]?\s*(on|enabled|automatic|activ|activat|automat|pornit)",
                    r"(windows update|update)\s*[:\-]?\s*(off|disabled|manual|oprit|dezactivat)",
                    r"(windows update|updates?).*(on|enabled|automatic|activ|activat|automat|pornit)",
                    r"(windows update|updates?).*(off|disabled|manual|oprit|dezactivat)",
                ],
                "positive_keywords": ["on", "enabled", "automatic", "activ", "activat", "automat", "pornit"],
                "negative_keywords": ["off", "disabled", "manual", "oprit", "dezactivat"],
            },
            "password_policy": {
                "patterns": [
                    r"(password|parol[ăa]).*(strong|complex|puternic[ăa]|enforced)",
                    r"(password|parol[ăa]).*(weak|simple|slab[ăa]|simpl[ăa])",
                ],
                "positive_keywords": ["strong", "complex", "puternica", "puternică", "puternic", "enforced"],
                "negative_keywords": ["weak", "simple", "slaba", "slabă", "simpla", "simplă", "simplu"],
            },
            "backup": {
                "patterns": [
                    r"(backup)\s*[:\-]?\s*(on|enabled|automatic|activ|activat|automat)",
                    r"(backup)\s*[:\-]?\s*(off|disabled|none|oprit|dezactivat|nu)",
                    r"backu[pb]\s*(on|enabled|automatic|activ|activat|automat)",
                    r"backu[pb]\s*(off|disabled|none|oprit|dezactivat|nu)",
                    r"[bg]ackup\s*(on|enabled|automatic|activ|activat|automat)",
                    r"[bg]ackup\s*(off|disabled|none|oprit|dezactivat|nu)",
                    r"[bg]ackup.*(on|enabled|automatic|activ|activat|automat)",
                    r"[bg]ackup.*(off|disabled|none|oprit|dezactivat|nu)",
                    r"(backup|file history|windows backup).*(on|enabled|automatic|activ|activat|automat)",
                    r"(backup|file history|windows backup).*(off|disabled|none|oprit|dezactivat|nu)",
                ],
                "positive_keywords": ["on", "enabled", "automatic", "activ", "activat", "automat"],
                "negative_keywords": ["off", "disabled", "none", "oprit", "dezactivat", "nu"],
            },
            "bitlocker": {
                "patterns": [
                    r"(bitlocker|encryption)\s*[:\-]?\s*(on|enabled|encrypted|activ|activat)",
                    r"(bitlocker|encryption)\s*[:\-]?\s*(off|disabled|unencrypted|oprit|dezactivat)",
                    r"(bitlocker|drive encryption|device encryption).*(on|enabled|encrypted|activ|activat)",
                    r"(bitlocker|drive encryption|device encryption).*(off|disabled|unencrypted|oprit|dezactivat)",
                ],
                "positive_keywords": ["on", "enabled", "encrypted", "activ", "activat"],
                "negative_keywords": ["off", "disabled", "unencrypted", "oprit", "dezactivat"],
            },
            "uac": {
                "patterns": [
                    r"(uac)\s*[:\-]?\s*(on|enabled|always notify|activ|activat|notificare)",
                    r"(uac)\s*[:\-]?\s*(off|disabled|never notify|oprit|dezactivat)",
                    r"(user account control|uac).*(on|enabled|always notify|activ|activat|notificare)",
                    r"(user account control|uac).*(off|disabled|never notify|oprit|dezactivat)",
                ],
                "positive_keywords": ["on", "enabled", "always notify", "activ", "activat", "notificare"],
                "negative_keywords": ["off", "disabled", "never notify", "oprit", "dezactivat"],
            },
        }

    def parse_text(self, text: str) -> dict:
        if not text or not text.strip():
            return {"error": "empty_text"}

        text_lower = text.lower()
        results = {
            "timestamp": datetime.now().isoformat(timespec="seconds"),
            "settings": {},
            "security_score": 0.0,
            "recommendations": [],
            "risks": [],
        }

        total = len(self.rules)
        positive = 0

        for setting_name, rule in self.rules.items():
            evidence: List[str] = []
            for pattern in rule["patterns"]:
                for m in re.finditer(pattern, text_lower, re.IGNORECASE | re.DOTALL):
                    snippet = m.group(0).strip()
                    if snippet and snippet not in evidence:
                        evidence.append(snippet[:200])

            detected = len(evidence) > 0
            status = "unknown"
            conf = 0

            if detected:
                evidence_text = " ".join(evidence)
                pos = sum(1 for kw in rule["positive_keywords"] if kw in evidence_text)
                neg = sum(1 for kw in rule["negative_keywords"] if kw in evidence_text)
                if pos > neg:
                    status = "secure"
                    positive += 1
                elif neg > pos:
                    status = "insecure"
                else:
                    status = "neutral"

                conf = min(100, 35 + (len(evidence) * 20) + min(20, (pos + neg) * 5))

            results["settings"][setting_name] = {
                "detected": detected,
                "status": status,
                "confidence": conf,
                "evidence": evidence,
            }

        if total:
            results["security_score"] = round((positive / total) * 100.0, 1)

        results["recommendations"] = self._generate_recommendations(results["settings"])
        results["risks"] = self._identify_risks(results["settings"])
        return results

    def _generate_recommendations(self, settings: Dict) -> List[str]:
        recs: List[str] = []
        if settings.get("firewall", {}).get("status") == "insecure":
            recs.append("🔴 Activează Windows Firewall.")
        if settings.get("antivirus", {}).get("status") == "insecure":
            recs.append("🔴 Activează/actualizează antivirusul (Windows Defender).")
        if settings.get("windows_update", {}).get("status") == "insecure":
            recs.append("🟡 Configurează Windows Update pe automat.")
        if settings.get("password_policy", {}).get("status") == "insecure":
            recs.append("🟡 Activează politici de parole puternice (complexitate).")
        if settings.get("backup", {}).get("status") == "insecure":
            recs.append("🔵 Configurează backup automat (File History/Windows Backup).")
        if settings.get("bitlocker", {}).get("status") == "insecure":
            recs.append("🔵 Activează criptarea disk-ului (BitLocker/Device encryption).")
        if settings.get("uac", {}).get("status") == "insecure":
            recs.append("🟡 Păstrează UAC activ (Always notify recomandat).")
        if not recs:
            recs.append("✅ Setările principale par OK (MVP).")
        return recs

    def _identify_risks(self, settings: Dict) -> List[str]:
        risks: List[str] = []
        insecure = [k for k, v in settings.items() if v.get("status") == "insecure"]
        if len(insecure) >= 3:
            risks.append("⚠️ RISK HIGH: multiple setări critice dezactivate.")
        elif len(insecure) >= 1:
            risks.append("⚠️ RISK MEDIUM: unele setări critice dezactivate.")
        if "antivirus" in insecure:
            risks.append("🦠 VIRUS RISK: antivirus dezactivat/outdated.")
        if "firewall" in insecure:
            risks.append("🌐 NETWORK RISK: firewall dezactivat.")
        return risks

    def analyze_file(self, file_path: str) -> dict:
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                text = f.read()
            analysis = self.parse_text(text)
            analysis["source_file"] = file_path
            return analysis
        except Exception as e:
            return {"error": str(e), "file": file_path}


def test_parser() -> dict:
    parser = SecuritySettingsParser()
    sample = """
Windows Security Status:
Windows Defender Firewall: ON
Antivirus protection: ON (UP TO DATE)
Windows Update: AUTOMATIC UPDATES ON
Password policy: STRONG
Backup: OFF
BitLocker: ENCRYPTED
User Account Control (UAC): ALWAYS NOTIFY
""".strip()
    out = parser.parse_text(sample)
    print(json.dumps(out, indent=2, ensure_ascii=False))
    return out


def main(argv: list[str]) -> int:
    if len(argv) >= 2 and argv[1] == "--test":
        test_parser()
        return 0
    if len(argv) >= 2:
        p = argv[1]
        parser = SecuritySettingsParser()
        if os.path.isfile(p):
            print(json.dumps(parser.analyze_file(p), indent=2, ensure_ascii=False))
            return 0
    print("Usage: python security_parser.py --test | <file.txt>")
    return 1


if __name__ == "__main__":
    import os
    raise SystemExit(main(list(sys.argv)))

