"""
Non-interactive OCR smoke test for VaultGuard OCR Engine.

Creates a demo image and runs OCR; exits non-zero on failure.
"""

from __future__ import annotations

import os
import sys

from ocr_engine import main as ocr_main, vault_root_from_this_file


def run() -> int:
    vault_root = vault_root_from_this_file()
    test_images = os.path.join(vault_root, "test_images")
    os.makedirs(test_images, exist_ok=True)
    # Run demo flow (creates demo_test.png and processes it)
    return ocr_main(["ocr_engine.py", "--demo", test_images])


if __name__ == "__main__":
    raise SystemExit(run())

