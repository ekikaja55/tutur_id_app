Penggunaan `const` pada `router.dart` milikmu secara umum **sudah hampir 90% tepat**!

Berikut pemetaannya agar kamu makin jelas membedakannya saat mengganti `PlaceholderScreen` dengan screen asli nantinya:

---

### 1. Wajib Gunakan `const` (Halaman Statis Tanpa Parameter)

Semua screen di bawah ini **TIDAK membaca parameter dari `state**`, sehingga instance widget-nya bersifat permanen/statis:

* `const AccessDeniedScreen()`
* `const PlaceholderScreen(title: "Login Page")`
* `const PlaceholderScreen(title: "Onboarding Page")`
* `const LearningHomeScreen()`
* `const PlaceholderScreen(title: "Subcription Page")`
* `const PlaceholderScreen(title: "Profile Page")`
* `const PlaceholderScreen(title: "Notification Page")`
* `const PlaceholderScreen(title: "Leaderboard Page")`
* **Seluruh Admin Routes:** `const PlaceholderScreen(title: "Admin - Dashboard Page")`, `users`, `content`, `broadcast`, `transactions`, `feedback`.

> **Alasan:** Parameter string seperti `title: "Login Page"` dipasok secara langsung (*string literal*), bukan dari variabel runtime.

---

### 2. DILARANG / Tidak Bisa Gunakan `const` (Halaman Dinamis)

Screen berikut membaca parameter dinamis dari `state.pathParameters` (di mana nilainya baru ketahuan saat user melakukan navigasi di runtime):

* **`ModuleDetailScreen(moduleId: moduleId)`**
$\rightarrow$ Karena `moduleId` adalah variabel.
* **`QuizScreen(moduleId: moduleId)`**
$\rightarrow$ Karena `moduleId` adalah variabel.
* **`PlaceholderScreen(title: "AI Camera Page", subTitle: "Id Module : $moduleId")`**
$\rightarrow$ Karena `subTitle` menggunakan *string interpolation* yang berisi variabel `$moduleId`.
* **`NotFoundScreen(attemptedPath: state.uri.toString())`**
$\rightarrow$ Karena `state.uri.toString()` dievaluasi saat runtime sesuai path yang dicoba oleh user.

---

### Catatan Penting Refactor Nanti:

Saat kamu mengganti `PlaceholderScreen` dengan screen asli (misal: `LoginScreen()`, `ProfileScreen()`, `UserManagementScreen()`):

1. Jika screen asli **tidak butuh parameter ID/arguments**, selalu gunakan `const`:
```dart
builder: (context, state) => const LoginScreen()

```


2. Jika screen asli **butuh ID dari path/query parameter**, buang kata kunci `const`:
```dart
builder: (context, state) {
  final userId = state.pathParameters['id']!;
  return UserDetailScreen(userId: userId); // TANPA const
}

```
