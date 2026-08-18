Bagus, ini penting dipastikan dulu sebelum banyak kode nulis field secara implisit. Aku susun struktur lengkap berdasarkan semua yang udah kita bahas sejauh ini.

## Struktur Firestore — Tutur.id

```
firestore/
│
├── users/{uid}
│   ├── uid: string
│   ├── email: string
│   ├── username: string
│   ├── phoneNumber: string | null
│   ├── photoUrl: string | null
│   ├── role: "student" | "admin"
│   ├── battery: number              // saldo baterai saat ini
│   ├── batteryLastRefill: timestamp // buat hitung refresh rate
│   ├── subscriptionTier: "starter" | "growth" | "ultimate"
│   ├── subscriptionExpiresAt: timestamp | null
│   ├── xp: number                   // total XP akumulasi
│   ├── streak: number                // hari belajar berturut-turut
│   ├── lastLoginDate: timestamp      // buat cek daily login & streak
│   └── createdAt: timestamp
│
├── user_progress/{uid}
│   ├── completedModules: array<string>   // list moduleId yang sudah selesai
│   └── updatedAt: timestamp
│
├── modules/{moduleId}
│   ├── id: string
│   ├── level: number              // 1, 2, 3
│   ├── title: string
│   ├── description: string
│   ├── type: "fingerspelling" | "lexical" | "spellingChallenge" | "masterChallenge"
│   ├── order: number
│   ├── materials: array<map>      // [{id, label, videoUrl, imageUrl}]
│   └── quizQuestions: array<map>  // [{id, question, options, correctOptionIndex}]
│
├── subscriptions/{uid}
│   ├── tier: "starter" | "growth" | "ultimate"
│   ├── startDate: timestamp
│   ├── expiresAt: timestamp | null
│   ├── status: "active" | "expired" | "cancelled"
│   └── lastTransactionId: string
│
├── transactions/{transactionId}
│   ├── id: string
│   ├── userId: string
│   ├── orderId: string             // dari Midtrans
│   ├── tier: "growth" | "ultimate"
│   ├── grossAmount: number
│   ├── status: "pending" | "success" | "failed" | "expired"
│   ├── paymentMethod: string | null
│   ├── createdAt: timestamp
│   └── updatedAt: timestamp
│
├── leaderboard/{uid}
│   ├── userId: string
│   ├── username: string
│   ├── photoUrl: string | null
│   ├── weeklyXp: number            // reset tiap Senin
│   ├── subscriptionTier: string    // buat kategori ranking per tier
│   └── updatedAt: timestamp
│
├── xp_logs/{logId}                 // audit trail, opsional tapi berguna
│   ├── userId: string
│   ├── amount: number
│   ├── source: "quiz" | "module_complete" | "ai_session" | "daily_quest"
│   ├── referenceId: string | null  // moduleId/questId terkait
│   └── createdAt: timestamp
│
├── daily_quests/{uid}
│   ├── date: string                // format "2026-07-28", reset tiap hari
│   ├── quests: array<map>
│   │   // [{id: "daily_login", completed: true, xpReward: 10}, ...]
│   └── updatedAt: timestamp
│
├── reports/{reportId}
│   ├── id: string
│   ├── userId: string
│   ├── category: "ai_camera" | "payment" | "material"
│   ├── description: string
│   ├── attachmentUrls: array<string>  // dari Cloudinary, max 2
│   ├── status: "diterima" | "diproses" | "selesai"
│   ├── adminResponse: string | null
│   ├── createdAt: timestamp
│   └── updatedAt: timestamp
│
├── feedback/{feedbackId}
│   ├── id: string
│   ├── userId: string
│   ├── rating: number              // 1-5 star
│   ├── description: string
│   ├── adminResponse: string | null
│   └── createdAt: timestamp
│
└── notifications/{uid}/messages/{messageId}
    ├── id: string
    ├── type: "system" | "gamification" | "transaction" | "report_response"
    ├── title: string
    ├── body: string
    ├── isRead: boolean
    ├── referenceId: string | null  // reportId/transactionId terkait
    └── createdAt: timestamp
```

## Catatan Desain Penting

### 1. Kenapa `battery` Disimpan di `users/{uid}`, Bukan Collection Terpisah?
Karena baterai itu **satu nilai tunggal per user** yang sering dibaca bareng data profil lain (misal saat cek "baterai cukup gak buat mulai sesi" — kita udah butuh `userProfileProvider` juga). Kalau dipisah jadi collection sendiri, jadi 2x round-trip Firestore tiap kali butuh data lengkap user. Beda kasus sama `xp_logs` yang sengaja dipisah karena sifatnya **historis/log**, bukan single value.

### 2. Kenapa `subscriptions` Terpisah dari `users`, Padahal Ada Field `subscriptionTier` di `users` Juga?
Ini **sengaja duplikasi terbatas** (denormalisasi), alasannya:
- `users.subscriptionTier` — dipakai buat **quick check** di banyak tempat (cek akses modul, cek limit baterai) tanpa perlu query collection lain.
- `subscriptions/{uid}` — nyimpan **detail histori langganan** (kapan mulai, kapan expired, status) yang gak perlu ikut kebawa tiap kali fetch `users`.

Konsekuensinya: **setiap kali status subscription berubah** (misal lewat webhook Midtrans), kamu harus update **kedua tempat** — field di `users` dan dokumen di `subscriptions`. Ini trade-off umum di NoSQL: duplikasi data demi read performance, tapi nambah tanggung jawab jaga konsistensi saat write.

### 3. Kenapa `leaderboard` Punya Field Sendiri (`username`, `photoUrl`), Padahal Bisa Di-join dari `users`?
Firestore **gak punya JOIN** seperti SQL. Kalau leaderboard cuma nyimpan `userId` + `weeklyXp`, buat nampilin daftar top 10 kamu harus fetch 10 dokumen tambahan ke `users` satu-satu buat ambil nama & foto — boros read quota. Makanya data yang **sering ditampilkan bareng** (nama, foto) di-**denormalisasi** langsung ke `leaderboard`. Trade-off-nya: kalau user ganti username, kamu perlu update juga entry leaderboard dia (bisa pakai Cloud Function trigger, atau untuk skala skripsi, update manual dari 2 tempat sekaligus).

### 4. Kenapa `notifications` Pakai Subcollection (`notifications/{uid}/messages/{messageId}`), Bukan Collection Datar?
Karena notifikasi **sifatnya privat per user** dan biasanya di-query "semua notif milik user ini, urut terbaru". Subcollection lebih natural buat pola akses ini — security rules juga jadi simpel (`allow read: if isOwner(userId)`), dan kamu gak perlu filter `where userId == uid` di collection besar yang isinya campur semua user.

### 5. `daily_quests/{uid}` — Field `date` Buat Apa?
Karena daily quest **reset tiap hari**, kamu butuh cara tau "data ini punya hari yang mana". Alternatifnya bisa juga `daily_quests/{uid}_{date}` sebagai document ID gabungan (misal `abc123_2026-07-28`), supaya histori tiap hari tetap ke-track (berguna kalau nanti mau bikin fitur "riwayat quest 30 hari terakhir"). Kalau kamu gak butuh histori, cukup 1 dokumen per user yang di-overwrite tiap hari — lebih simpel tapi histori sebelumnya hilang. Mana yang kamu mau?

## Field yang Perlu Kamu Tambahkan ke `UserModel` (Update dari yang Sudah Dibuat)

Berdasarkan struktur ini, `UserModel` yang kita buat di `features/auth/` masih kurang beberapa field:

```dart
class UserModel {
  // ... field yang sudah ada
  final DateTime? batteryLastRefill;
  final DateTime? subscriptionExpiresAt;
  final int xp;
  final int streak;
  final DateTime? lastLoginDate;
  // ...
}
```

Mau aku update `UserModel` sekalian sekarang, atau nanti aja pas kita masuk ke fitur gamification/subscription (biar gak bolak-balik edit file yang sama)?
