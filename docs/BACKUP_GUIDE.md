# Database & Backup Guide — HR Enterprise

Yeh guide bataati hai ke is app ka data kahan store hota hai aur uska backup kaise lena hai.

> **Note:** Backup/export ke liye Firebase project ka **Blaze (pay-as-you-go) plan** zaroori hai.
> Free **Spark** plan pe yeh features nahi chalte. Chhote data pe kharcha taqreeban $0 hota hai
> (sirf storage aur operations ka mamooli charge).

---

## 1. Database kahan hai?

- **Database:** Cloud Firestore
- **Firebase project:** `hr-enterprise-92fac`
- **Storage (files/images):** Firebase Storage

App ka saara data Firestore collections mein hai:
`users`, `employees`, `attendance`, `leaves`, `payroll`, `onboarding`,
`notifications`, `audit_logs`, `google_sheets`, `company_settings`.

Database pehle se bana hua hai — alag se "database banane" ki zaroorat nahi.

---

## 2. Blaze plan pe upgrade kaise karein

1. https://console.firebase.google.com/project/hr-enterprise-92fac/usage/details
2. Neeche **"Modify plan"** / **"Upgrade"** par click karein
3. **Blaze – Pay as you go** chunein
4. Billing account (credit/debit card) add karein
5. Confirm karein

Chahein to **budget alert** laga lein (e.g. $5/month) taake kharcha control mein rahe.

---

## 3. gcloud CLI install (ek dafa)

Backup commands ke liye Google Cloud CLI chahiye:

1. Download: https://cloud.google.com/sdk/docs/install
2. Install ke baad terminal mein:
   ```bash
   gcloud auth login
   gcloud config set project hr-enterprise-92fac
   ```

---

## 4. Option A — Managed Daily Backups (RECOMMENDED, sabse aasaan)

Firebase khud rozana backup leta hai aur retention period tak rakhta hai.

### Set up (ek dafa):
```bash
gcloud firestore backups schedules create \
  --database="(default)" \
  --recurrence=daily \
  --retention=14d \
  --project=hr-enterprise-92fac
```

### Backups dekhne ke liye:
```bash
gcloud firestore backups list --project=hr-enterprise-92fac
```

### Schedule dekhne/delete karne ke liye:
```bash
gcloud firestore backups schedules list --database="(default)"
gcloud firestore backups schedules delete SCHEDULE_ID --database="(default)"
```

### Restore (kisi backup se naya database banana):
```bash
gcloud firestore databases restore \
  --source-backup=projects/hr-enterprise-92fac/locations/LOCATION/backups/BACKUP_ID \
  --destination-database=restored-db
```
> Restore hamesha ek **naye** database mein hota hai (default ko overwrite nahi karta),
> phir aap data verify kar ke shift kar sakte hain.

---

## 5. Option B — Scheduled Export to Cloud Storage

Apne control mein, long-term backup ke liye. Data ek Storage bucket mein export hota hai.

### Manual export (jab chahein):
```bash
gcloud firestore export gs://hr-enterprise-92fac-backups \
  --project=hr-enterprise-92fac
```
(Pehli dafa bucket banana hoga:
`gsutil mb -l asia-south1 gs://hr-enterprise-92fac-backups`)

### Automatic daily export (Cloud Scheduler se):
Firebase Console → Firestore → **Import/Export** → **Schedule exports** se UI ke zariye
daily export set kar sakte hain (sabse simple), ya `gcloud scheduler` se cron laga sakte hain.

### Import (restore):
```bash
gcloud firestore import gs://hr-enterprise-92fac-backups/EXPORT_FOLDER \
  --project=hr-enterprise-92fac
```

---

## 6. Quick manual backup (bina schedule ke)

Kabhi-kabhi ek dafa backup chahiye to:
```bash
gcloud firestore export gs://hr-enterprise-92fac-backups/manual-$(date +%Y%m%d)
```

---

## 7. Kaunsa chunein?

| Zaroorat | Behtareen option |
|----------|------------------|
| "Bas safe rehna hai, kam mehnat" | **Option A — Managed Daily Backups** |
| "Data apne bucket mein, lambe arse tak" | **Option B — Scheduled Export** |
| "Sirf abhi ek backup chahiye" | **Option 6 — Manual export** |

**Mashwara:** Pehle Blaze pe jayein → phir Option A (daily backups) set kar lein.
Yeh 2 minute ka kaam hai aur rozana automatic backup de deta hai.

---

## 8. Yeh bhi backup kar lein (code/config)

Data ke ilawa yeh cheezein bhi mehfooz rakhein:
- **Code:** Git repo (GitHub par push karte rahein)
- **Firestore rules/indexes:** `firestore.rules`, `firestore.indexes.json` (repo mein hain)
- **Firebase config:** `lib/firebase_options.dart`, `lib/firebase_secrets.dart`
  (yeh secrets hain — public repo mein commit na karein)
