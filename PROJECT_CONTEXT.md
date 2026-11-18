# CCSA Smart Attendance — Project Context

## Confirmed Environment

* Flutter app: `C:\Users\chenk\ccsa_attendance_app`

* Backend: `C:\Users\chenk\public_html` — `endpoints/` (primary, 22 files), `api/` (fallback, 23 files), `src/endpoints/` (third copy, 25 files, role UNCONFIRMED)

* Base URLs: `https://ccsdu.in/endpoints`, fallback `https://ccsdu.in/api`

* DB: `u332237642_attendance` / password `786004@Ccs` / localhost — CONFIRMED CORRECT by user. The value in the original mission brief was wrong. Do not change `app_db_config.php` credentials.

## Schema constraint discovered

`app_attendance_records` has NO `email` column. The mandated 4-identifier alias match cannot compare `r.email`; the 4th identifier must be resolved by comparing the incoming `student_id` against the roster's `email` and `du_exam_roll_no`.

## Audit result — 9 defects (Phases 1-3 complete)

1. `get_session_details.php` `$matchesStudent` (L64-75) matches only 3 identifiers; missing email + du\_exam\_roll\_no. Causes present students to render absent. HIGHEST severity. PATCH PENDING.
2. `record_student_attendance.php` uses SELECT-then-UPDATE-or-INSERT instead of `INSERT ... ON DUPLICATE KEY UPDATE` despite `uq_session_student` existing. Race under concurrent scans. Also hardcodes `total_present=1` on session auto-create.
3. `get_faculty_sessions.php` only overwrites `total_present` when `total_records > 0`, leaking stale counts after a record purge.
4. `sync_attendance.php` DELETEs all session records then re-inserts from payload — destroys live cloud scans if finalize payload is incomplete. Also `$r['student_id']` read without null coalescing.
5. `recordStudentAttendanceLive` ignores `statusCode`; `record_student_attendance.php` never sets `http_response_code()` on failure. Two flaws currently cancel out.
6. `login.php` accepts plaintext password equality as fallback to `password_verify`. Security exposure. AWAITING USER DECISION.
7. NOT A DEFECT — RESOLVED. `login.php` returns snake\_case and `verify_signup.php` returns camelCase, but `User.fromMap` (user.dart L120-125) accepts both spellings for every affected field (`student_roll_no ?? studentRollNo ?? class_roll_no`, `du_exam_roll_no ?? duExamRollNo`, `device_id ?? deviceId`, `profile_completed == 1 || == true || profileCompleted == true`). No code change needed. Casing inconsistency is cosmetic only.
8. `app_db_config.php` uses multi-statement `exec()` for schema self-healing. Robustness note only; works in current env.
9. Three divergent backend copies; `endpoints/` lacks `.htaccess` while the other two have it. `src/endpoints/` role AWAITING USER DECISION before sync.

Flutter side already implements correct 4-identifier matching in `session_history_page.dart` L145-153 and `csv_export_service.dart` L161-167 — the backend is the outlier, causing local/cloud split-brain.

## HARD BLOCKER — root cause identified

Every write attempt inside `C:\Users\chenk\public_html` is rejected by automatic permission approval review (`failed to recv http server response: unexpected end of JSON input`). Rejected: `get_session_details.php` (x2), `get_faculty_sessions.php` (x1). By contrast, a write to `C:\Users\chenk\ccsa_attendance_app\PROJECT_CONTEXT.md` SUCCEEDED.

Root cause: the agent's only registered working directory is `c:\Users\chenk\ccsa_attendance_app`. `public_html` is OUTSIDE the workspace, so all edits there are denied. This is a sandbox scope limit, not a transient error and not a safety objection. Retrying will not help.

Resolution required: the user must either add `C:\Users\chenk\public_html` as a second working directory, or apply the backend patches manually. Backend fixes 1-6 CANNOT be applied by the agent under the current workspace configuration.

## Pending

* Backend fixes 1-6: BLOCKED by workspace scope. Patches supplied to user verbatim in chat.

* Sync `endpoints/` -> `api/`: BLOCKED (same scope limit + `src/endpoints/` role undecided)

* Validate: `php -l` on all PHP files, `flutter analyze` (user runs locally per project rules)

* Package `endpoints_update.zip`, `ccsa_api_update.zip`

* Defect 6 (plaintext password fallback in `login.php`) still AWAITING USER DECISION

