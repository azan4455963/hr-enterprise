# Google Drive Integration — Setup Guide

App mein "Google Drive" option ke zariye aap kayi Drive folders link kar sakte ho.
Lekin un folders ke andar ki **sheets ka data parhne** ke liye ek **one-time Google
Cloud setup** zaroori hai. Yeh steps aap (ya aap ka developer) ko karne honge —
iske baad mujhe **OAuth Client ID** de dena, main app mein live fetch + search jodd dunga.

> Billing/Blaze zaroori NAHI — Drive & Sheets API free quota mein aa jati hain.

---

## Step 1 — APIs enable karein

1. https://console.cloud.google.com/ → apna project (`hr-enterprise-92fac`) chunein
2. **APIs & Services → Library**
3. Yeh do enable karein:
   - **Google Drive API**
   - **Google Sheets API**

## Step 2 — OAuth consent screen

1. **APIs & Services → OAuth consent screen**
2. User type: **External** (ya Internal agar Workspace ho)
3. App name, support email bharein → Save
4. **Scopes** add karein:
   - `https://www.googleapis.com/auth/drive.readonly`
   - `https://www.googleapis.com/auth/spreadsheets.readonly`
5. **Test users** mein apna Gmail add karein (jab tak app "Testing" mode mein hai)

## Step 3 — OAuth Client ID banayein

1. **APIs & Services → Credentials → Create Credentials → OAuth client ID**
2. Web app ke liye (Chrome / web build):
   - Application type: **Web application**
   - **Authorized JavaScript origins**: `http://localhost` aur aap ka deployed domain
   - Client ID copy karein (e.g. `xxxx.apps.googleusercontent.com`)
3. Android/iOS build ke liye alag client IDs banane honge (platform ke hisaab se).

## Step 4 — Client ID app mein daalein

- **Web:** `web/index.html` ke `<head>` mein:
  ```html
  <meta name="google-signin-client_id" content="YOUR_CLIENT_ID.apps.googleusercontent.com">
  ```
- Mujhe Client ID bhej dena — baqi wiring (sign-in button, Drive fetch, search) main kar dunga.

---

## Step 5 — Folders share karein

Jo Drive folders aap link karoge, woh us Google account ke paas accessible hone chahiye
jisse aap app mein **"Connect Google Drive"** karte ho (ya us account ki apni hi drive ho).

---

## Kaam kaise karega (setup mukammal hone ke baad)

1. App mein **Google Drive → Link Drive** se folders add karo (abhi bhi kar sakte ho)
2. **Connect Google Drive** se sign-in karke ijazat do
3. App har linked folder ke andar ki **saari Google Sheets** dhoondh leta hai
4. Un sheets ka data **employee search** mein chala jata hai — naam ya email type karo,
   to drive ki sab sheets se us banday ki info aa jati hai

---

## Abhi (setup se pehle) kya kaam karta hai

- Drive folders **link / unlink** karna — ✅ chal raha hai (Firestore mein save)
- Folder ID extraction — ✅
- Sheets ka actual data fetch + search — ⏳ Client ID milne ke baad
