# HR Enterprise — Production Flutter + Firebase HR System

Cross-platform HR platform (Android, iOS, Web, Windows, macOS) with real-time Firestore data, RBAC, QR attendance, PDF/Excel export, and push notifications.

## Production features (implemented)

| Module | Capabilities |
|--------|----------------|
| **Auth** | Email/password, Google, forgot password, remember me, biometric unlock |
| **RBAC** | Role permissions in Firestore + route guards + `PermissionGate` widgets |
| **Attendance** | Manual check-in/out, **QR scan**, admin QR display, late detection, Firestore logs |
| **Employees** | CRUD, profile upload, document storage, auto-link user by email |
| **Onboarding** | Secure links, multi-step form, draft save, file upload, approve → employee |
| **Leave** | Date picker requests, manager approval, notifications |
| **Payroll** | Create records, mark paid, role-protected salary |
| **Dashboard** | Live stats, 7-day bar chart, payroll summary |
| **Reports** | PDF (printing) + Excel export with real Firestore data |
| **Notifications** | FCM + local notifications + in-app Firestore feed |
| **Settings** | Dark/light theme, company hours, biometric toggle |

## UI / Design system

The authenticated app uses a **light "HR Command" design** (navy + blue accent on a light canvas). The login/register screens keep their dedicated photo backdrop.

- **Palette & tokens** — [`lib/core/theme/app_colors.dart`](lib/core/theme/app_colors.dart): navy `#1E3A8A`, blue `#2563EB`, light canvas, white cards, status colors.
- **Reusable UI kit** — [`lib/core/widgets/ui_kit.dart`](lib/core/widgets/ui_kit.dart): `AppCard`, `StatCard`, `StatusPill`, `PageHeading`, `SectionTitle`, `PrimaryButton`, `GhostButton`, `InitialAvatar`, `StatCardRow`. Build new screens from these so the look stays consistent.
- **App shell** — [`lib/features/shell/app_shell.dart`](lib/features/shell/app_shell.dart): light sidebar (brand, nav, Add Employee CTA, Settings/Logout footer) + a shared **"HR Command"** top bar (search, notifications, settings, profile) rendered on every screen.
- **Redesigned screens** — Dashboard, Employees, Attendance & Leaves, Onboarding. Payroll / Reports / Settings still use the legacy style.

> Login backdrop lives in [`lib/core/widgets/login_backdrop.dart`](lib/core/widgets/login_backdrop.dart) (photo + overlay); other screens sit on the light canvas via the shell.

## Setup (required)

### 1. Firebase project

```bash
cd hr_enterprise
dart pub global activate flutterfire_cli
flutterfire configure
```

Enable: **Authentication** (Email + Google), **Firestore**, **Storage**, **Cloud Messaging**.

### 2. Deploy security rules

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```

### 3. Run

```bash
flutter pub get
flutter run -d windows
```

### 4. First Super Admin

1. Register a user in the app.
2. In Firestore Console → `users/{uid}` set:

```json
{
  "role": "super_admin",
  "permissions": ["*"]
}
```

3. Create employees and set matching `email` on employee + user `employeeId` field (or use **Add Employee** — auto-links by email).

## QR attendance flow

1. Admin: **Attendance → Show QR** (generates 30-min session).
2. Display **Check In** / **Check Out** QR codes at office.
3. Employee: **Attendance → Scan QR** (validates session + records in Firestore).

## Roles & permissions

- `super_admin` — full access (`*`)
- `admin` / `hr_manager` — HR operations
- `manager` — department view + leave approval
- `employee` — attendance, leave requests

Unauthorized routes redirect to `/unauthorized`.

## Project structure

```
lib/
├── bootstrap.dart          # DI overrides
├── core/                   # theme, router, validators, QR format
├── models/
├── services/               # Firebase + export + messaging
├── providers/
└── features/               # UI modules
```

## Push notifications

- Mobile: FCM token saved to `fcm_tokens/{userId}` on login.
- Foreground: local notification + Firestore `notifications` entry.
- Send broadcasts via `MessagingService.notifyRole()` (in-app; extend with Cloud Functions for true push-to-device).

## License

Private / internal use.
