"""
OCR Improvement Test (Windows Security focused)

Runs keyword-assisted OCR on all images in ~/vaultguard/test_images and writes:
  ~/vaultguard/ocr_improvement_report.json
"""

from __future__ import annotations

import json
import os
from datetime import datetime


def main() -> int:
    userprofile = os.environ.get("USERPROFILE")
    if not userprofile:
        print("USERPROFILE not set")
        return 1

    vault = os.path.join(userprofile, "vaultguard")
    test_dir = os.path.join(vault, "test_images")
    report_path = os.path.join(vault, "ocr_improvement_report.json")

    if not os.path.isdir(test_dir):
        print(f"Missing test_images: {test_dir}")
        return 1

    # Import installed engine from vaultguard/ocr
    import sys

    sys.path.insert(0, os.path.join(vault, "ocr"))
    from ocr_engine import extract_with_keyword_assist  # type: ignore

    images = [f for f in os.listdir(test_dir) if f.lower().endswith((".png", ".jpg", ".jpeg", ".bmp"))]
    images.sort()

    results = []
    for name in images:
        p = os.path.join(test_dir, name)
        try:
            r = extract_with_keyword_assist(p)
            text_preview = (r.get("text") or "")[:300]
            results.append(
                {
                    "file": name,
                    "mode": r.get("mode"),
                    "processing_time_s": r.get("processing_time_s"),
                    "keyword_count": r.get("keyword_count"),
                    "keywords_found": r.get("keywords_found"),
                    "text_preview": text_preview,
                }
            )
        except Exception as e:
            results.append({"file": name, "error": str(e)})

    ok = [r for r in results if "error" not in r]
    avg_kw = (sum(r.get("keyword_count", 0) for r in ok) / len(ok)) if ok else 0.0
    avg_time = (sum(r.get("processing_time_s", 0.0) for r in ok) / len(ok)) if ok else 0.0

    report = {
        "test_date": datetime.now().isoformat(timespec="seconds"),
        "ocr_engine_version": "enhanced_windows_security_v1",
        "total_images": len(results),
        "ok_images": len(ok),
        "avg_keywords_per_image": round(avg_kw, 2),
        "avg_processing_time_s": round(avg_time, 3),
        "detailed_results": results,
    }

    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)

    print(report_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

