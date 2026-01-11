"""
VAULTGUARD OCR + SECURITY ANALYZER (SUBPUNCT 2.3.3)

Flow:
  images (test_images/) -> OCR -> extracted text file (ocr_results/) -> parse -> JSON + report (security_results/)

Usage:
  python security_analyzer.py <image_path|folder_path>
  python security_analyzer.py  (defaults to ~/vaultguard/test_images)
"""

from __future__ import annotations

import json
import os
import sys
from datetime import datetime


def vault_dir() -> str:
    userprofile = os.environ.get("USERPROFILE")
    if userprofile:
        return os.path.join(userprofile, "vaultguard")
    # fallback
    return os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


def ensure_paths():
    # Add vaultguard/ocr and vaultguard/security to sys.path when running from installed location.
    base = vault_dir()
    sys.path.insert(0, os.path.join(base, "ocr"))
    sys.path.insert(0, os.path.join(base, "security"))


def list_images(folder: str) -> list[str]:
    exts = (".png", ".jpg", ".jpeg", ".bmp", ".tif", ".tiff", ".webp")
    imgs = []
    for name in os.listdir(folder):
        if name.lower().endswith(exts):
            imgs.append(os.path.join(folder, name))
    return sorted(imgs)


def write_text(path: str, content: str):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)


class VaultGuardSecurityAnalyzer:
    def __init__(self):
        ensure_paths()
        from ocr_engine import extract_text, save_result  # type: ignore
        from security_parser import SecuritySettingsParser  # type: ignore

        self.vault = vault_dir()
        self.extract_text = extract_text
        self.save_result = save_result
        self.parser = SecuritySettingsParser()

        self.results_dir = os.path.join(self.vault, "security_results")
        os.makedirs(self.results_dir, exist_ok=True)

    def analyze_image(self, image_path: str) -> dict:
        base = os.path.splitext(os.path.basename(image_path))[0]
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")

        # Prefer the Windows Security OCR mode when available.
        try:
            ocr = self.extract_text(image_path, mode="windows_security")
        except TypeError:
            ocr = self.extract_text(image_path)
        ocr_txt_path = self.save_result(self.vault, image_path, ocr)

        ocr_text = ocr.get("text", "") or ""
        analysis = self.parser.parse_text(ocr_text)
        analysis["source_image"] = os.path.basename(image_path)
        analysis["ocr_text_file"] = ocr_txt_path
        analysis["ocr_text_len"] = len(ocr_text)

        payload = {
            "timestamp": ts,
            "image": os.path.basename(image_path),
            "ocr": ocr,
            "security_analysis": analysis,
            "ocr_text_excerpt": ocr_text[:400],
        }

        json_path = os.path.join(self.results_dir, f"{base}_analysis.json")
        with open(json_path, "w", encoding="utf-8") as f:
            json.dump(payload, f, indent=2, ensure_ascii=False)

        report_path = os.path.join(self.results_dir, f"{base}_report.txt")
        self._write_report(report_path, payload)

        return {
            "json": json_path,
            "report": report_path,
            "score": analysis.get("security_score", 0.0),
        }

    def analyze_folder(self, folder: str) -> dict:
        imgs = list_images(folder)
        out = {
            "folder": folder,
            "count": len(imgs),
            "results": [],
            "timestamp": datetime.now().isoformat(timespec="seconds"),
        }
        for i, img in enumerate(imgs, 1):
            print(f"[{i}/{len(imgs)}] {os.path.basename(img)}")
            r = self.analyze_image(img)
            out["results"].append(r)
        summary_path = os.path.join(self.results_dir, f"SUMMARY_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json")
        with open(summary_path, "w", encoding="utf-8") as f:
            json.dump(out, f, indent=2, ensure_ascii=False)
        out["summary"] = summary_path
        return out

    def _write_report(self, path: str, payload: dict):
        a = payload.get("security_analysis", {})
        lines = []
        lines.append("=" * 60)
        lines.append("VAULTGUARD SECURITY ANALYSIS REPORT (MVP)")
        lines.append("=" * 60)
        lines.append(f"Image: {payload.get('image')}")
        lines.append(f"Timestamp: {payload.get('timestamp')}")
        lines.append(f"Security score: {a.get('security_score')}%")
        lines.append("")
        lines.append("SETTINGS:")
        for k, v in (a.get("settings") or {}).items():
            if v.get("detected"):
                lines.append(f"- {k}: {v.get('status')} (conf {v.get('confidence')}%)")
        lines.append("")
        lines.append("RISKS:")
        for r in a.get("risks") or []:
            lines.append(f"- {r}")
        lines.append("")
        lines.append("RECOMMENDATIONS:")
        for r in a.get("recommendations") or []:
            lines.append(f"- {r}")
        lines.append("")
        write_text(path, "\n".join(lines) + "\n")


def main(argv: list[str]) -> int:
    analyzer = VaultGuardSecurityAnalyzer()
    target = argv[1] if len(argv) >= 2 else os.path.join(vault_dir(), "test_images")

    if os.path.isdir(target):
        res = analyzer.analyze_folder(target)
        print(json.dumps(res, indent=2, ensure_ascii=False))
        return 0
    if os.path.isfile(target):
        res = analyzer.analyze_image(target)
        print(json.dumps(res, indent=2, ensure_ascii=False))
        return 0

    print(f"Invalid path: {target}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

