# REMOTE WORKFLOW — Cursor 24/7 Execution Protocol

**Objective:** Continuous progress with auto-recovery and no manual “try again”.

---

## Principles
- **Never stall**: if a step fails, automatically attempt diagnosis + fix + re-run.
- **Preserve state**: every meaningful checkpoint produces a backup artifact.
- **Proof-driven**: progress is only “done” when build/tests show it.

---

## Protocol: How Cursor runs work continuously

### 1) Execution loop
- Pick next todo from roadmap (smallest actionable unit).
- Implement change.
- Run the smallest validating command (build/test) relevant to the change.
- Log results to `reports/` (timestamped).
- If failure: run recovery → re-run validation → if still failing, rollback to last backup and continue with a safer approach.

### 2) Progress reporting automation (every 4 hours)
Use existing monitoring scripts as the engine:
- `monitoring/hourly_intelligent_reporter.ps1` (adapt schedule to 4h in Task Scheduler)
- `monitoring/recovery_orchestrator.ps1` for auto-recovery loops

Output location:
- `reports/` (status reports, summaries)
- `backups/` (zip checkpoints)

---

## Auto-recovery procedures (no manual “try again”)

### Common failure patterns & actions
- **Gradle dependency/network failures**
  - Run recovery build script (refresh deps + retry)
  - If still failing, switch to offline mode if cache is warm
- **Kotlin compile errors**
  - Fix compile error, re-run `:app:assembleDebug`
- **Manifest/merge errors**
  - Fix manifest or resources, re-run build
- **R8/ProGuard failures**
  - Adjust `app/proguard-rules.pro`, re-run `:app:assembleRelease`

### Rollback policy
- Before risky changes, create a backup:
  - `scripts/backup_after_subpoint.ps1`
- If recovery fails after N attempts:
  - Restore the latest `backups/*.zip`
  - Re-apply changes in smaller steps

---

## Build failure automatic rollback

### Suggested strategy
- Attempt recovery up to **3** times (with different strategies: refresh-deps, clean, offline).
- If still failing:
  - Restore last green backup
  - Produce a “failure incident report” in `reports/`

---

## Offline mode guarantee

### When offline mode is valid
- Gradle caches contain all required dependencies
- No new dependency versions are introduced in the change

### Command rule
- Always support an `--offline` build path (see `scripts/offline_build.sh` / `scripts/offline_build.ps1`).

