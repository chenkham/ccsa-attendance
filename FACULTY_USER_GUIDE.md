# CCSAAS — Faculty User Guide
**CCSA Attendance System** · Centre for Computer Science and Applications, Dibrugarh University

This guide explains every feature of the CCSAAS app and how to use it correctly. The app works on **Android phones, Windows desktops, and as a web app (PWA)** — all three stay connected to the same central database, so anything you do on one device appears on the others after a refresh.

---

## 1. Installing the App

| Platform | How to install |
|---|---|
| **Android** | Get the APK file (`CCSAAS-Android-v3.0.0.apk`), tap it, and allow *“Install from unknown sources”* when asked. One-time only. |
| **Windows** | Get `CCSAAS-Windows-v3.0.0.zip`, right-click → *Extract All*, then double-click `ccsa_smart_attendance.exe`. No installation needed. |
| **Web / PWA** | Open the college web link in Chrome. You can also tap *“Add to Home screen”* to use it like an app. |

> If you previously installed an older version and Android refuses to update, uninstall the old one first — this is only needed once.

---

## 2. Account — Sign Up & Sign In

### First time (Sign Up)
1. Open the app → choose the **Create Account** tab.
2. Select your role: **Faculty**.
3. Pick your name from the **Faculty directory** (or choose *Guest Faculty* and type your name).
4. Enter your **email** and a **password** (min 6 characters).
5. Tap **Create Account**. A **6-digit OTP code** is emailed to you (check Spam if not in Inbox).
6. Enter the OTP in the dialog → your account is created and you're signed in automatically.

### Returning (Sign In)
Enter your email + password → **Sign In**. Your session stays saved on the device until you sign out.

### Forgot Password?
Tap **Forgot Password?** on the sign-in screen:
1. Enter your registered email → a **6-digit code** is emailed to you.
2. Enter the code → set a new password.
3. Sign in with the new password.

### Profile & Security (Profile tab)
- **Change Password** — verifies your current password, then updates it.
- **Change Email** — verifies your current password, then updates it.
- **Hardware Device Binding** — shows this device's ID and whether biometrics (fingerprint/face) are available.

---

## 3. Faculty Dashboard (Home)

The home screen shows:
- **Greeting header** — your name, today's date.
- **Subjects / Total Classes / Total Present** — live counters synced from the university database.
- **Attendance chart** — per-subject attendance percentage; **green = Safe (≥80%)**, red = Shortage.
- **My Assigned Subjects** — search by name/code, filter by programme (BCA/MCA/PGDCA), and tap any subject to open it.

**Pull down** anywhere on the page to refresh from the server.

Quick actions:
- **Add Subject** — create a new subject (see §4).
- **Session Logs** — open past sessions of your first subject.
- **Export All** — download attendance sheets of every subject (CSV files).

---

## 4. Creating a Subject

1. Tap **Add Subject**.
2. Fill in **Subject Name, Subject Code, Teacher Name**.
3. Choose **Programme (BCA/MCA/PGDCA)** and **Semester** — the app loads all registered students of that class automatically.
4. *(Optional)* **Classroom GPS Geofencing** — restrict scanning to your classroom (see §7).
5. Select the enrolled students (tap **Select All** or pick individually; use the search box).
6. Tap **Create Subject**.

> **Students who register later** can be added anytime from *Subject Details → Add Student*, and their previous attendance can be imported from the physical register (see §8).

---

## 5. Taking Attendance (Live QR Session)

Open a subject → tap **Start Attendance**.

1. A **QR code appears that changes automatically every 3 seconds** — students cannot photograph and reuse it.
2. Students open the CCSAAS app on their phones → **Scan** → point at the screen.
3. The **Live Turnout card** updates within ~1 second for each scan, showing Present / Absent counts and a progress bar.
4. Students who can't scan (dead phone, cracked camera) — tap **Manual Roll Call Override** and mark them **Present** by hand.
5. **Full Screen** (top-right icon) — a projector-friendly view for classroom displays.
6. When class ends → **Done & Save Session**. The whole session is saved to the university database and every student's history updates.
7. **Cancel Session** — opened by mistake? Cancel discards everything; nothing is saved.

> Attendance also requires the student to confirm with **fingerprint/face unlock** on their phone, and — if you enabled geofencing — to be physically inside your classroom.

---

## 6. Editing or Deleting Past Sessions

Open a subject → **Past Sessions** tab.

- Tap any session card → the **attendance sheet** opens with every student listed.
- Tap **Edit** (pencil) → each student gets **Present / Absent** toggle chips. Flip anyone's status — the summary counts update live.
- Tap **Save Changes** → corrections sync to the central database and every student's percentage recalculates.
- **Delete** (red trash icon on a session card) → after a clear warning, the session and its records are permanently removed from the database.
- **Previous Register Attendance** card — your imported register records (see §8); tap to view, trash icon to delete the whole import.

---

## 7. Classroom Geofencing (Location Restriction)

Open a subject → tap the **map-pin icon** in the top bar.

- **Live map** shows your classroom with a blue **radius circle** (in real meters).
- **Toggle ON/OFF** — when ON, students can only scan inside the circle.
- **My GPS (high accuracy)** — stand in your classroom, press the button, hold still ~5–10 seconds. The app locks onto the most precise satellite fix (it shows the accuracy, e.g. *±8m*) and moves the pin to your exact spot.
- **Radius slider** — 20 to 200 meters. 40–60m works well for a classroom block.
- **Save** — applies everywhere immediately, for every device.

The pin icon is **green when geofencing is active**, gray when off. The QR code students scan carries this restriction — the app rejects scans from outside the circle.

---

## 8. Importing Previous Attendance from the Physical Register

For classes already held before you started using the app (or for students who joined late):

1. Open the subject → tap the **book icon** in the top bar.
2. Enter **Total Classes Held on Register**.
3. For each student, set how many of those classes they attended using the **[−] count [+]** stepper.
   - **All to Max** — everyone attended everything.
   - **Joined Late** — set a late-joining student to 0.
4. Tap **Import to Database**.

The import creates the past sessions in the database. **Re-importing safely replaces** the previous register data — it never duplicates. Live QR sessions are never touched.

---

## 9. Exports

- **One subject** — Subject Details → spreadsheet icon → follow the export dialog (CSV file, shared/saved via your device).
- **Everything** — Dashboard → **Export All**.
- CSV files open in Excel/Google Sheets.

---

## 10. Student Side (what your students see)

Students see their overall attendance gauge, per-subject percentages, their full history, and a big **Scan** button. Their attendance status is classified as **Regular (≥80%)**, **NC (70–80%)**, or **DC (<70%)**, and a subject is **Eligible** at ≥80%. They scan your classroom QR, confirm with fingerprint/face, and their record appears on your live turnout instantly.

---

## 11. Troubleshooting

| Problem | Fix |
|---|---|
| “Unable to connect / nothing loads” | Check internet. All data lives on the college server — the app needs a connection. |
| OTP email not arriving | Wait a minute, check **Spam**, then request a new code. |
| Student scan says “Outside Classroom!” | Geofencing is ON and they're outside the radius. Verify your geofence location (§7) or increase radius, or turn it off. |
| Live turnout not updating | It refreshes automatically every second; pull down to refresh if the internet was interrupted. |
| Student says they scanned but show Absent | Open the session sheet → **Edit** → flip them to Present → Save. |
| Wrong numbers after register import | Re-import with corrected counts — it **replaces** the old register data, no duplicates. |
| Deleted a session by mistake | Sessions can't be recovered after deletion — this is why the app asks for confirmation twice. |

---

*For technical/architecture details, see `DEVELOPER_GUIDE.md`.*
