"""
VAULTGUARD OCR ENGINE (Windows MVP)

- Offline OCR using Tesseract (via pytesseract)
- Batch processes a folder of images
- Saves results to: <vaultguard_root>/ocr_results/

Usage:
  python ocr_engine.py <image_path>
  python ocr_engine.py <folder_path>
  python ocr_engine.py --demo <output_folder>
  python ocr_engine.py --improve <folder_path>
"""

from __future__ import annotations

import os
import sys
import time
from datetime import datetime


SECURITY_KEYWORDS = [
    "firewall",
    "antivirus",
    "windows update",
    "update",
    "bitlocker",
    "uac",
    "user account control",
    "backup",
    "password",
    "encryption",
    "defender",
    "security",
    "protection",
    "enabled",
    "disabled",
    "active",
    "automatic",
    "manual",
    "risk",
]


def vault_root_from_this_file() -> str:
    # .../vaultguard/ocr/ocr_engine.py -> vaultguard/
    return os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


def default_tesseract_path() -> str:
    return r"C:\Program Files\Tesseract-OCR\tesseract.exe"


def configure_tesseract() -> tuple[bool, str]:
    try:
        import pytesseract  # noqa: F401
    except Exception as e:  # pragma: no cover
        return False, f"pytesseract import failed: {e}"

    try:
        import pytesseract
        tpath = os.environ.get("VAULTGUARD_TESSERACT_PATH") or default_tesseract_path()
        if os.path.exists(tpath):
            pytesseract.pytesseract.tesseract_cmd = tpath
            return True, tpath
        return False, tpath
    except Exception as e:  # pragma: no cover
        return False, f"tesseract configure failed: {e}"


def ensure_tesseract_configured() -> bool:
    """
    Ensure pytesseract has a usable tesseract_cmd even when this module is imported and used as a library.
    """
    ok, _ = configure_tesseract()
    return bool(ok)


def preprocess_cv(image_path: str):
    import cv2
    import numpy as np

    img = cv2.imread(image_path)
    if img is None:
        raise ValueError(f"Cannot read image: {image_path}")

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    denoised = cv2.medianBlur(gray, 3)

    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    enhanced = clahe.apply(denoised)

    # Otsu binarization
    _, binary = cv2.threshold(enhanced, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

    # Scale small images up a bit (helps screenshots with small fonts)
    h, w = binary.shape[:2]
    if max(h, w) < 1200:
        scale = 2.0
        binary = cv2.resize(binary, None, fx=scale, fy=scale, interpolation=cv2.INTER_CUBIC)

    # Light morphology to close small gaps
    kernel = np.ones((2, 2), np.uint8)
    binary = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel, iterations=1)

    return binary


def enhanced_preprocess_for_windows_security(image_path: str):
    """
    Enhanced preprocessing for Windows Security screenshots:
    - stronger contrast enhancement
    - upscale for thin UI fonts
    - invert if text is light-on-dark
    - light edge/contour-based masking to focus on UI "cards"
    """
    import cv2
    import numpy as np

    img = cv2.imread(image_path)
    if img is None:
        raise ValueError(f"Cannot read image: {image_path}")

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # Upscale first to help thin fonts
    h, w = gray.shape[:2]
    if max(h, w) < 1600:
        gray = cv2.resize(gray, None, fx=2.0, fy=2.0, interpolation=cv2.INTER_CUBIC)

    # Contrast enhancement
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
    enhanced = clahe.apply(gray)

    # If UI is dark mode (white text on dark background), invert for Tesseract.
    if float(np.mean(enhanced)) < 110.0:
        enhanced = cv2.bitwise_not(enhanced)

    # Mild denoise
    enhanced = cv2.medianBlur(enhanced, 3)

    # Edge detection -> contours -> build a mask of likely text containers
    edges = cv2.Canny(enhanced, 50, 150)
    contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    mask = np.zeros_like(enhanced)
    for c in contours:
        x, y, cw, ch = cv2.boundingRect(c)
        # Heuristic: Windows UI cards/buttons sizes (after upscale)
        if 250 < cw < 2000 and 60 < ch < 350:
            cv2.rectangle(mask, (x, y), (x + cw, y + ch), 255, -1)

    focused = cv2.bitwise_and(enhanced, enhanced, mask=mask) if int(np.sum(mask)) > 0 else enhanced

    # Binarize
    _, binary = cv2.threshold(focused, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

    # Small morphology to connect broken strokes
    kernel = np.ones((2, 2), np.uint8)
    binary = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel, iterations=1)

    return binary


def extract_text(
    image_path: str,
    lang: str = "ron+eng",
    preprocess: bool = True,
    mode: str | None = None,
) -> dict:
    import pytesseract
    from PIL import Image

    if not ensure_tesseract_configured():
        raise RuntimeError("Tesseract not configured (tesseract.exe not found).")

    start = time.time()
    if preprocess:
        if mode == "windows_security":
            arr = enhanced_preprocess_for_windows_security(image_path)
        else:
            arr = preprocess_cv(image_path)
        img = Image.fromarray(arr)
    else:
        img = Image.open(image_path)

    # Default config. For Windows UI, whitelist common characters to reduce noise.
    if mode == "windows_security":
        config = '--oem 3 --psm 6 -c tessedit_char_whitelist="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 :.-()[]/%"'
    else:
        config = "--oem 3 --psm 6"
    text = pytesseract.image_to_string(img, lang=lang, config=config)
    elapsed = time.time() - start

    return {
        "text": (text or "").strip(),
        "lang": lang,
        "processing_time_s": elapsed,
        # pytesseract image_to_string doesn't return confidence; we keep a placeholder.
        "confidence_est": None,
        "timestamp": datetime.now().isoformat(timespec="seconds"),
        "mode": mode or "default",
    }


def extract_with_keyword_assist(
    image_path: str,
    keywords: list[str] | None = None,
    lang: str = "ron+eng",
) -> dict:
    """
    OCR with Windows Security preprocessing + keyword detection. Returns OCR text + keyword hits.
    """
    keywords = keywords or SECURITY_KEYWORDS
    result = extract_text(image_path, lang=lang, preprocess=True, mode="windows_security")
    text_lower = (result.get("text") or "").lower()
    found = [kw for kw in keywords if kw.lower() in text_lower]
    return {
        **result,
        "keywords_found": found,
        "keyword_count": len(found),
    }

def save_result(vault_root: str, image_path: str, result: dict) -> str:
    out_dir = os.path.join(vault_root, "ocr_results")
    os.makedirs(out_dir, exist_ok=True)
    base = os.path.splitext(os.path.basename(image_path))[0]
    out_path = os.path.join(out_dir, f"{base}_extracted.txt")

    with open(out_path, "w", encoding="utf-8") as f:
        f.write("# VaultGuard OCR Extract\n")
        f.write(f"# Image: {os.path.basename(image_path)}\n")
        f.write(f"# Date: {result.get('timestamp')}\n")
        f.write(f"# Lang: {result.get('lang')}\n")
        f.write(f"# ProcessingTimeS: {result.get('processing_time_s'):.3f}\n")
        f.write("=" * 60 + "\n\n")
        f.write(result.get("text", "") + "\n")

    return out_path


def list_images(folder: str) -> list[str]:
    exts = (".png", ".jpg", ".jpeg", ".bmp", ".tif", ".tiff", ".webp")
    files = []
    for name in os.listdir(folder):
        if name.lower().endswith(exts):
            files.append(os.path.join(folder, name))
    return sorted(files)


def create_demo_image(out_path: str):
    from PIL import Image, ImageDraw
    from PIL import ImageFont

    img = Image.new("RGB", (1100, 500), color="white")
    d = ImageDraw.Draw(img)

    try:
        font = ImageFont.truetype("arial.ttf", 34)
    except Exception:
        font = ImageFont.load_default()

    lines = [
        "VaultGuard Security OCR Demo",
        "Windows Security: ON",
        "Firewall: ENABLED",
        "Antivirus: UP TO DATE",
        "SmartScreen: ENABLED",
        "Password policy: STRONG",
        "Backup: OFF (RISK)",
    ]
    y = 30
    for line in lines:
        d.text((40, y), line, fill="black", font=font)
        y += 55

    img.save(out_path)


def main(argv: list[str]) -> int:
    vault_root = vault_root_from_this_file()

    ok, tpath = configure_tesseract()
    if not ok:
        print("❌ Tesseract not configured / not installed.")
        print(f"Expected at: {tpath}")
        print("Install from: https://github.com/UB-Mannheim/tesseract/wiki")
        return 2

    if len(argv) >= 2 and argv[1] == "--demo":
        out_folder = argv[2] if len(argv) >= 3 else os.path.join(vault_root, "test_images")
        os.makedirs(out_folder, exist_ok=True)
        demo_path = os.path.join(out_folder, "demo_test.png")
        create_demo_image(demo_path)
        print(f"✅ Demo image created: {demo_path}")
        res = extract_text(demo_path)
        out = save_result(vault_root, demo_path, res)
        print(f"✅ OCR OK. Saved: {out}")
        return 0

    if len(argv) >= 2 and argv[1] == "--improve":
        folder = argv[2] if len(argv) >= 3 else os.path.join(vault_root, "test_images")
        if not os.path.isdir(folder):
            print(f"❌ Folder not found: {folder}")
            return 1
        images = list_images(folder)
        if not images:
            print(f"⚠ No images found in: {folder}")
            return 0
        for i, p in enumerate(images, 1):
            print(f"[{i}/{len(images)}] OCR+keywords: {os.path.basename(p)}")
            res = extract_with_keyword_assist(p)
            out = save_result(vault_root, p, res)
            print(f"   Saved: {out} keywords={res['keyword_count']}")
        return 0

    if len(argv) < 2:
        print("Usage: python ocr_engine.py <image_path|folder_path|--demo [out_folder]>")
        return 1

    target = argv[1]
    if os.path.isdir(target):
        images = list_images(target)
        if not images:
            print(f"⚠ No images found in: {target}")
            return 0
        print(f"🔍 Found {len(images)} image(s) in {target}")
        for i, p in enumerate(images, 1):
            print(f"[{i}/{len(images)}] OCR: {os.path.basename(p)}")
            res = extract_text(p)
            out = save_result(vault_root, p, res)
            print(f"   Saved: {out} (t={res['processing_time_s']:.2f}s)")
        return 0

    if os.path.isfile(target):
        print(f"OCR: {target}")
        res = extract_text(target)
        out = save_result(vault_root, target, res)
        print(f"Saved: {out} (t={res['processing_time_s']:.2f}s)")
        return 0

    print(f"❌ Invalid path: {target}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

