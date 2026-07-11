# Railway + Resend Auth Emails

Firebase Auth kullanıcı yönetimini tutar; e-posta gönderimini Resend yapar.

## Akış

Flutter → Railway (`/auth/...`) → Firebase Admin (link) → Resend → kullanıcı

## Railway Variables

| Variable | Zorunlu | Örnek |
|----------|---------|--------|
| `RESEND_API_KEY` | Evet | `re_...` |
| `RESEND_FROM_EMAIL` | Evet | `Tombik Teyze <noreply@domain.com>` |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Evet (zaten var) | service account JSON |
| `FIREBASE_EMAIL_CONTINUE_URL` | Hayır | `https://falora35.firebaseapp.com` |

## Endpointler

- `POST /auth/send-verification-email` — `Authorization: Bearer <idToken>`
- `POST /auth/send-password-reset-email` — body `{ "email": "..." }` (auth yok)

## Deploy

Kod `main`’e push edilince Railway otomatik deploy eder (mevcut repo bağlantısı).
