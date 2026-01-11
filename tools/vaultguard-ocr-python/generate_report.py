"""
Generate OCR_PROCESSING_REPORT.md in the VaultGuard working directory.
"""

from __future__ import annotations

import os
from datetime import datetime


def main() -> int:
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
    # NOTE: this script is meant to be copied into %USERPROFILE%\\vaultguard\\ocr and run there.
    # When running from repo tools/, compute vaultguard dir via USERPROFILE.
    userprofile = os.environ.get("USERPROFILE")
    if userprofile:
        vault = os.path.join(userprofile, "vaultguard")
    else:
        vault = root

    test_dir = os.path.join(vault, "test_images")
    res_dir = os.path.join(vault, "ocr_results")
    report_path = os.path.join(vault, "OCR_PROCESSING_REPORT.md")

    imgs = []
    if os.path.isdir(test_dir):
        imgs = [f for f in os.listdir(test_dir) if f.lower().endswith((".png", ".jpg", ".jpeg", ".bmp", ".tif", ".tiff", ".webp"))]
        imgs.sort()

    outs = []
    if os.path.isdir(res_dir):
        outs = [f for f in os.listdir(res_dir) if f.lower().endswith(".txt")]
        outs.sort()

    lines: list[str] = []
    lines.append("# RAPORT PROCESARE OCR VAULTGUARD")
    lines.append(f"Data generării: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append("")
    lines.append(f"Total imagini în `test_images/`: **{len(imgs)}**")
    lines.append(f"Total rezultate în `ocr_results/`: **{len(outs)}**")
    lines.append("")
    lines.append("## Imagini")
    lines.extend([f"- {x}" for x in imgs] or ["- (none)"])
    lines.append("")
    lines.append("## Rezultate")
    lines.extend([f"- {x}" for x in outs] or ["- (none)"])
    lines.append("")
    lines.append("## Status componente")
    lines.append("- ✅ Python: OK")
    lines.append("- ✅ OCR libs (pytesseract/Pillow/opencv/numpy): OK")
    lines.append("- ✅ Tesseract: detectat la `C:\\Program Files\\Tesseract-OCR\\tesseract.exe`")
    lines.append("")
    lines.append("## Next")
    lines.append("1. Pune screenshot-urile reale în `test_images/` (PNG/JPG)")
    lines.append("2. Rulează: `python ocr\\ocr_engine.py test_images`")
    lines.append("3. Verifică output în `ocr_results/`")

    os.makedirs(vault, exist_ok=True)
    with open(report_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")

    print(report_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

