# CCSAAS — Developer Guide
**CCSA Attendance System** · Architecture, API map, database schema, and operations

This document explains how CCSAAS is built end-to-end: the app architecture, every backend endpoint, the database schema, deployment workflow, and build/release process. It's the reference for maintaining and extending the system.

---

## 1. What the System Is

A cross-platform **dynamic-QR attendance system**:

- **Flutter app** (one Dart codebase) compiled to **Android**, **Windows**, and **Web/PWA**
- **PHP + MySQL backend** on Hostinger (`https://ccsdu.in/endpoints`) — the single source of truth
- **Time-rotating TOTP QR codes** (3-second HMAC tokens) so QRs can't be screenshotted and reused
- Optional **GPS geofencing** enforced per subject, embedded into the QR payload
- **Local SQLite cache** on mobile/desktop for offline fallback; web runs with in-memory storage

```
┌─────────────┐   HTTPS/JSON   ┌──────────────────┐   PDO   ┌─────────────────┐
│ Flutter app │ ─────────────▶ │ ccsdu.in/endpoints │ ──────▶ │ MySQL            │
│ Android     │ ◀───────────── │ (PHP endpoints)    │ ◀────── │ u332237642_attend│
│ Windows Web │                └──────────────────┘          └─────────────────┘
│      │      │
│  SQLite     │  ← offline cache (mobile/desktop only)
└─────────────┘
```

## 2. App Tech Stack

| Layer | Technology |
|---|---|
| UI framework | Flutter 3.x (Dart), Material 3 |
| State | Per-page `StatefulWidget` + `setState` (no external state lib) |
| Auth storage | `shared_preferences` (persisted session) + SQLite `users` table |
| Local DB | `sqflite` / `sqflite_common_ffi` (desktop) / `sqflite_common_ffi_web` (web, in-memory) |
| HTTP | `package:http`, JSON bodies, 20s timeout, single base URL |
| QR generation | `qr_flutter` + `crypto` (HMAC-SHA256 TOTP payloads, 3s window) |
| QR scanning | `mobile_scanner` (Android/iOS only; desktop/web show a graceful notice) |
| GPS | `geolocator` — stream-based high-accuracy capture (best-fix-in-10s, ±12m target) |
| Maps | `flutter_map` + OpenStreetMap tiles (no API key needed) |
| Biometrics | `local_auth` (fingerprint/face; auto-allows when hardware absent) |
| Icons/fonts | `lucide_icons`, `google_fonts` (Inter + Plus Jakarta Sans) |
| App icon | `flutter_launcher_icons` from `assets/icons/app_icon_*.png` |

### Key source layout

```
lib/
├── main.dart                  # DB factory init, service init, MaterialApp (title: CCSAAS)
├── theme/app_theme.dart       # Design system: colors, motion tokens, component themes
├── models/                    # User, Student, Subject, AttendanceSession(+Record)
│   └── ...                    #   .fromMap() tolerates snake_case & camelCase from APIs
├── services/
│   ├── api_service.dart       # ALL backend calls (base: https://ccsdu.in/endpoints)
│   ├── auth_service.dart      # Session persistence, login/signup/profile logic
│   ├── device_security_service.dart  # Hardware device ID + biometric auth
│   ├── location_service.dart  # GPS + high-accuracy capture + geofence math
│   └── totp_qr_service.dart   # 3-second rotating QR payload gen/validate (HMAC-SHA256)
├── db/database_helper.dart    # Local SQLite schema + CRUD (cache layer)
├── widgets/                   # Shared UI: charts, gauges, doodle art, micro-interactions
└── pages/
    ├── auth/login_page.dart   # Sign in/up + OTP flows (email OTP via backend SMTP)
    ├── faculty/               # Dashboard, create subject, subject details, QR session,
    │                          #   session history
    ├── student/               # Dashboard, QR scanner, history
    ├── common/settings_page.dart, profile/profile_page.dart
    └── splash/splash_page.dart
```

## 3. Backend — PHP Endpoints

**Production base URL:** `https://ccsdu.in/endpoints`
⚠️ `/src/endpoints` and `/api` return 404 on the live server — the app uses `/endpoints` only. The deployable source of truth is the local folder `C:\Users\chenk\public_html\src\endpoints\`.

All endpoints return JSON (`{success: bool, message, ...data}`), send CORS headers, accept JSON or form POST (GET for queries), and self-heal the schema on first connection (`app_db_config.php`).

### Auth chain
| Endpoint | Method | App payload → response |
|---|---|---|
| `check_user_exists.php` | POST | `{email,name,role}` → `{exists}` (blocks duplicate signup) |
| `send_otp.php` | POST | `{email,name,type:signup\|reset}` → emails 6-digit OTP (5-min expiry, table `app_otp_verifications`) |
| `verify_signup.php` | POST | `{email,otp,name,password,role,course,semester,...}` → creates user (bcrypt), student row; returns camelCase user |
| `login.php` | POST | `{email,password,device_id}` → `{user}` (snake_case); auto-migrates legacy plaintext→bcrypt; auto-binds device ID |
| `verify_reset_otp.php` | POST | `{email,otp}` → validates reset code |
| `reset_password.php` | POST | `{email,otp,new_password}` → bcrypt update |
| `change_password.php` | POST | `{email,current_password,new_password}` |

### Subjects & rosters
| Endpoint | Method | Notes |
|---|---|---|
| `sync_subject.php` | POST | Upsert subject + **replace** enrollment rows (`app_subject_students`), transactional |
| `get_faculty_subjects.php` | GET `?email=` | Subjects + `enrolled_students[]` + `enrolled_student_ids[]` |
| `get_student_subjects.php` | GET `?email&student_id` | Resolves ID across `app_users`/`app_students` |
| `get_registered_students.php` | GET `?course&semester` | UNION of `app_students` + student-role `app_users` |
| `update_profile.php` | POST | Updates user + student profile, roll numbers |
| `delete_subject.php` | POST | Cascading delete: enrollments → records → sessions → subject |

### Attendance
| Endpoint | Method | Notes |
|---|---|---|
| `record_student_attendance.php` | POST | Live QR scan. Strict identity match (student_id OR roll_no — **never name**, never rewrites identifiers → prevents duplicate-row turnout inflation). Counts turnout with `COUNT(DISTINCT)` |
| `get_session_turnout.php` | GET `?session_id=` | `{present_students:[rows]}` — app counts **unique students** (not identifiers) |
| `sync_attendance.php` | POST | Finalize session: upsert session + records (preserves record ids → live scans not lost), dedupes by identity, **recounts from DB**, transactional |
| `get_faculty_sessions.php` | GET `?email=` or `?subject_id=` | Sessions **with `records[]`** attached (per-student sheets + roster %) |
| `get_student_attendance.php` | GET `?email&student_id` | Per-subject `{total_held, total_attended, percentage, sessions[]}` |
| `get_session_details.php` | GET `?session_id=` | Unified sheet: enrolled roster ⊕ raw records, 6-way identity matching |
| `delete_subject_sessions.php` | POST | `{subject_id, id_prefix}` — deletes matching sessions+records. Powers both register-baseline replace-on-reimport (`baseline_<subjectId>_`) and single-session delete |

### Collation pitfall (solved)
MySQL error 1267 occurs when a bound parameter is compared directly against a string literal (`? != ''`) under mixed collations. Rule: **build conditional clauses in PHP**, compare only column↔parameter.

## 4. Database Schema (MySQL `u332237642_attendance`)

Tables (created/patched automatically by `app_db_config.php`):
- `app_users` — id (uuid), name, email (unique), password (bcrypt), role(student|faculty), student_roll_no, du_exam_roll_no, course, semester, designation, department, device_id, profile_completed
- `app_students` — student roster keyed by id/email (dup of user data for roster math)
- `app_subjects` — id, code, name, course, semester, teacher_name, teacher_email, geofence_lat/lng/radius
- `app_subject_students` — (subject_id, student_id) junction, PK composite
- `app_attendance_sessions` — id, subject_*, session_date, total_present, total_enrolled, is_lab, geofence columns
- `app_attendance_records` — id, session_id, student_id, student_roll_no, student_name, status(present|absent), marked_by(totp_qr|manual_teacher|physical_register|system), UNIQUE(session_id, student_id)
- `app_otp_verifications` — email, otp_code, expires_at, is_used

### Identity matching rule (used consistently in PHP + Dart)
A record matches a student by: `student_id` → id, **or** `student_roll_no` → class_roll_no, **or** `student_name` → name (case-insensitive), plus email/du_exam_roll_no variants in sheet views. Live-scan writes never match on name (two students can share one).

### Local SQLite (cache only)
Mirror tables: `users, students, subjects, subject_students, attendance_sessions, attendance_records`. Cloud is authoritative; local is reconciled on every dashboard load (prunes cloud-deleted rows). Register imports use **deterministic session ids** `baseline_<subjectId>_<n>` so re-imports replace cleanly.

## 5. The Dynamic QR Security Model

1. Faculty device generates payload: `subjectId|sessionId|HMAC-SHA256(secret, subjectId+sessionId+timeWindow)` with a **3-second** rotating window (`totp_qr_service.dart`).
2. Student scans → app recomputes the HMAC for ±1 window tolerance → expired/invalid QR rejected.
3. Then: GPS check (if geofence ON, +15m indoor tolerance) → device binding → biometric confirm → duplicate-check → `record_student_attendance.php`.
4. Teacher's screen polls `get_session_turnout.php` every **800ms**; turnout = unique students.

## 6. Deployment Workflow

**Backend (Hostinger hPanel File Manager):**
1. Edit PHP in `C:\Users\chenk\public_html\src\endpoints\` (this mirrors production).
2. `php -l <file>` locally to lint.
3. Upload changed files into **`public_html/endpoints/`** (or upload a zip → Extract Here).
4. Verify live: `curl -X POST https://ccsdu.in/endpoints/<file>.php -H "Content-Type: application/json" -d '{...}'`

Current status: `record_student_attendance.php`, `get_faculty_sessions.php`, `delete_subject_sessions.php` were patched locally — **upload them if not done yet**.

**App builds (PowerShell):**
```powershell
cd C:\Users\chenk\ccsa_attendance_app

# Android (signed; arm64 covers modern phones; ~28MB)
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols

# Windows
flutter build windows --release

# Web/PWA
flutter build web --release        # deploy build\web\ to hosting

# Regenerate launcher icons after changing assets/icons/*
dart run flutter_launcher_icons
```

**Android signing** (keep safe — required for every update):
- Keystore `android/ccsaas-release.jks`, alias `ccsaas`, password `CCSAAS2025release`, loaded via `android/key.properties` (gitignored)

**Distributables:** `build\distro\CCSAAS-Android-v3.0.0.apk` (28.3MB), `CCSAAS-Android-v3.0.0-old32bit.apk` (23.2MB), `CCSAAS-Windows-v3.0.0.zip` (13.9MB)

## 7. Performance & Size Notes

- Dashboard/detail loads run their API calls **in parallel** (`Future.wait`)
- Live-session polling: 800ms; manual marks update UI instantly
- Size: removed dead 5.2MB `mobilefacenet.tflite`; per-ABI APKs; icon/font tree-shaking → **~28MB arm64 APK** (was 84MB universal)
- Known caveat: `split-per-abi` APKs and the previous universal build have different signatures history — users may need a one-time uninstall when switching

## 8. Extending the System

- **New endpoint**: copy an existing PHP file, keep the `app_db_config.php` require (CORS + DB + schema self-heal), add a method in `api_service.dart` using `_postToCloud`/`_getFromCloud`
- **New local table**: bump `_dbVersion` in `database_helper.dart` and add `ALTER TABLE` in `onUpgrade`
- **Model changes**: keep `.fromMap` tolerant (`?? fallbacks`) — MySQL returns ints as strings through PDO in this setup

---

*End-user instructions: see `FACULTY_USER_GUIDE.md`.*
