# VaultGuard Revolution - ProGuard / R8 rules
#
# Keep this minimal and tighten as we confirm release builds.

# --- Kotlin metadata (helps reflection-based libs) ---
-keep class kotlin.Metadata { *; }

# --- ML Kit ---
# ML Kit uses internal loading; keep its internal classes safe from overly aggressive shrinking.
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# --- CameraX ---
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# --- Compose (generally safe; rules are mostly handled by AGP/Compose tooling) ---
-dontwarn androidx.compose.**

# --- VaultGuard packages ---
-keep class com.vaultguard.** { *; }
-keep class com.example.vaultguard.** { *; }

