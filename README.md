# EzyHelpers - Helper Partner Mini App

A full-stack mobile workflow application built for the **EzyHelpers 48-Hour Full-Stack Developer Assessment**. 

The solution enables service helpers to sign in, view their assigned jobs, inspect job details, update job status (`ASSIGNED` → `IN_PROGRESS` → `COMPLETED`) with strict state-transition enforcement, and stream user actions to **Firebase Analytics**.

---

## Architecture Overview

```
               ┌────────────────────────────────────────────────────────┐
               │                  Flutter Mobile App                    │
               │   • Login Screen (Form validation, demo autofill)      │
               │   • Jobs List Screen (Loading, Empty, Error states)    │
               │   • Job Details Screen (Status Stepper, Action Button) │
               │   • Provider State Management + ApiService             │
               └──────────────┬──────────────────────────┬──────────────┘
                              │                          │
                 REST API (HTTP / Token Auth)    Firebase Analytics SDK
                              │                          │
                              ▼                          ▼
               ┌──────────────────────────────┐   ┌─────────────────────┐
               │    Django REST Framework     │   │ Firebase Analytics  │
               │   • Token Authentication     │   │   (DebugView)       │
               │   • FSM Status Transitions   │   │  • login_success    │
               │   • Helper Ownership Check   │   │  • job_viewed       │
               │   • SQLite / PostgreSQL DB   │   │  • job_status_update│
               └──────────────────────────────┘   └─────────────────────┘
```

### Key Technical Choices
- **Backend**: Python 3.12+ / Django 6.1 + Django REST Framework. Uses token-based authentication, custom permission checks ensuring helpers can only query and mutate their own jobs, strict status validation FSM returning `409 Conflict` on invalid transitions, and automated test coverage (17 test cases).
- **Mobile**: Flutter (Dart 3) with `provider` for reactive state, persistent authentication via `shared_preferences`, and centralized theme styling.
- **Analytics**: `firebase_core` & `firebase_analytics` logging key user lifecycle events guarded against hot-restart duplicate-app collisions.

---

## Demo Credentials

The backend includes pre-configured helper accounts to verify ownership isolation:

| Helper | Username | Password | Role / Access |
|---|---|---|---|
| **Primary Helper** | `helper1` | `DemoPass123!` | Has 4 assigned jobs across all 3 statuses |
| **Secondary Helper** | `helper2` | `DemoPass123!` | Has separate jobs; cannot view or modify `helper1` jobs |

---

## Quick Start Guide

### 1. Backend Setup (Django REST Framework)

```bash
cd backend

# 1. Create and activate virtual environment
python3 -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# 2. Install dependencies
pip install -r requirements.txt

# 3. Apply database migrations
python manage.py migrate

# 4. Seed demo helpers and sample jobs
python manage.py seed_demo

# 5. Run the development server
python manage.py runserver 0.0.0.0:8000
```

The backend API will be available at `http://127.0.0.1:8000/`.

---

### 2. Mobile App Setup (Flutter)

```bash
cd mobile

# 1. Install Flutter dependencies
flutter pub get

# 2. Configure environment variables (if not present)
cp .env.example .env

# 3. If running on an Android Emulator or Physical Device connected via USB:
# Route port 8000 on the Android device back to your local machine
adb reverse tcp:8000 tcp:8000

# 4. Run the app
flutter run
```

> **Note on Android Networking:** If you do not use `adb reverse tcp:8000 tcp:8000`, change `BASE_URL` in `mobile/.env` to `http://10.0.2.2:8000` (the standard Android emulator loopback alias).

---

## API Contract & Examples

### 1. Helper Login
- **Endpoint**: `POST /api/auth/login/`
- **Headers**: `Content-Type: application/json`
- **Request Body**:
```json
{
  "username": "helper1",
  "password": "DemoPass123!"
}
```
- **Response** (`200 OK`):
```json
{
  "token": "9944b09199c62bcf9418ad846dd0e4bbdfc6ee4b",
  "user_id": 1,
  "username": "helper1"
}
```

### 2. Helper Logout
- **Endpoint**: `POST /api/auth/logout/`
- **Headers**: `Authorization: Token <token>`
- **Response**: `204 No Content` (Invalidates the auth token).

### 3. List Assigned Jobs
- **Endpoint**: `GET /api/jobs/`
- **Headers**: `Authorization: Token <token>`
- **Response** (`200 OK`):
```json
[
  {
    "id": 4,
    "title": "Kitchen Plumbing Repair",
    "description": "Fix leaking pipe under the kitchen sink and inspect drain pressure.",
    "location": "742 Evergreen Terrace, Springfield",
    "scheduled_at": "2026-10-22T07:27:04.998492Z",
    "status": "ASSIGNED"
  },
  {
    "id": 3,
    "title": "Deep House Cleaning",
    "description": "Living room, 2 bedrooms, and kitchen dusting, vacuuming, and mopping.",
    "location": "124 Conch Street, Bikini Bottom",
    "scheduled_at": "2026-10-22T04:27:04.998492Z",
    "status": "IN_PROGRESS"
  }
]
```

### 4. Get Job Details
- **Endpoint**: `GET /api/jobs/{id}/`
- **Headers**: `Authorization: Token <token>`
- **Response** (`200 OK`):
```json
{
  "id": 4,
  "title": "Kitchen Plumbing Repair",
  "description": "Fix leaking pipe under the kitchen sink and inspect drain pressure.",
  "location": "742 Evergreen Terrace, Springfield",
  "scheduled_at": "2026-10-22T07:27:04.998492Z",
  "status": "ASSIGNED"
}
```
*(Returns `404 Not Found` if the job belongs to another helper, enforcing ownership).*

### 5. Update Job Status
- **Endpoint**: `PATCH /api/jobs/{id}/status/`
- **Headers**: 
  - `Authorization: Token <token>`
  - `Content-Type: application/json`
- **Request Body**:
```json
{
  "status": "IN_PROGRESS"
}
```
- **Response** (`200 OK`):
```json
{
  "id": 4,
  "title": "Kitchen Plumbing Repair",
  "status": "IN_PROGRESS"
}
```
- **Error Responses**:
  - `409 Conflict`: If an illegal transition is attempted (e.g. `ASSIGNED` → `COMPLETED`, or backwards transition from `IN_PROGRESS` → `ASSIGNED`, or updating an already `COMPLETED` job).
  - `400 Bad Request`: If status is invalid or missing.
  - `404 Not Found`: If job is not owned by the authenticated helper.

---

## Firebase Analytics & DebugView Verification

The app integrates Firebase Analytics and logs the 3 required events:

| Event Name | Trigger | Parameters |
|---|---|---|
| `login_success` | Logged immediately upon successful login credentials check | None |
| `job_viewed` | Logged whenever a helper opens a job's detail screen | `job_id` (int) |
| `job_status_updated` | Logged whenever a status transition succeeds | `job_id` (int), `new_status` (string) |

### How to Verify Events in Firebase DebugView

1. Connect your Android device or start an Android Emulator.
2. Enable debug logging for the application package:
   ```bash
   adb shell setprop debug.firebase.analytics.app com.example.mobile
   ```
3. Open the Firebase Console:
   - Navigate to **Analytics** → **DebugView**.
4. Perform actions in the app:
   - Log in (`login_success` appears in the timeline).
   - Tap any job card (`job_viewed` appears with `job_id`).
   - Click **Start Job** or **Complete Job** (`job_status_updated` appears with `new_status`).
5. To disable debug logging after testing:
   ```bash
   adb shell setprop debug.firebase.analytics.app .none.
   ```

---

## Testing

### Automated Backend Tests
Run the complete backend test suite:
```bash
cd backend
python manage.py test
```

**Coverage includes 17 tests:**
- `AuthTests`: Token generation on login, invalid password rejection, missing field validation, token revocation on logout.
- `JobReadTests`: Unauthenticated request rejection, strict helper ownership filtering (helpers cannot see or query others' jobs).
- `JobStatusUpdateTests`: Valid `ASSIGNED -> IN_PROGRESS -> COMPLETED` progression, rejection of skip-to-completed (`409 Conflict`), rejection of backwards transition, immutability of `COMPLETED` jobs, foreign job modification rejection (`404 Not Found`).

---

## Build Artifacts (Debug APK)

To build a standalone debug APK for device deployment:

```bash
cd mobile
flutter build apk --debug
```

The output file is generated at:
```
mobile/build/app/outputs/flutter-apk/app-debug.apk
```

---

## Known Limitations & Design Decisions

1. **Local Database**: Built with SQLite by default for zero-setup local evaluation. The data layer is decoupled and can seamlessly switch to PostgreSQL in `settings.py` via `DATABASE_URL` for production deployments.
2. **Local Transport Security**: Development uses HTTP (`http://127.0.0.1:8000`). Production requires HTTPS and SSL certificate pinning.
3. **Session Storage**: Auth tokens are persisted using `SharedPreferences`. In production enterprise apps, hardware-backed secure storage (`flutter_secure_storage` with Android Keystore & iOS Keychain) is recommended.
4. **Offline Sync**: The app currently operates online against the real API. Offline request queueing is categorized under stretch goals.

---

## Completed vs. Deferred Scope

| Feature / Requirement | Status | Implementation Details |
|---|---|---|
| Helper Authentication API (`/api/auth/login/`, `logout/`) | Completed | DRF Token Authentication |
| Assigned Jobs Listing (`/api/jobs/`) | Completed | Isolated to authenticated helper |
| Job Details API (`/api/jobs/{id}/`) | Completed | Enforces helper ownership |
| Status Transition FSM (`/api/jobs/{id}/status/`) | Completed | Validates `ASSIGNED -> IN_PROGRESS -> COMPLETED`, returns 409 Conflict |
| Persistent DB & Seed Data | Completed | SQLite + `python manage.py seed_demo` |
| Flutter Screens (Login, List, Details) | Completed | Clean modern UI with animations, badges, stepper |
| Loading / Empty / Error States | Completed | Complete with retry actions and error banners |
| Pull-to-Refresh | Completed | Supported on job listing screen |
| Firebase Analytics Integration | Completed | `login_success`, `job_viewed`, `job_status_updated` |
| Backend Automated Tests | Completed | 17 passing test cases |
| Debug APK Build | Completed | `mobile/build/app/outputs/flutter-apk/app-debug.apk` |
| Pull Request & Git Feature Branch | Completed | `feature/helper-job-workflow` branch |
| Push Notifications (FCM) / Offline Caching | Deferred | Optional stretch goals |
