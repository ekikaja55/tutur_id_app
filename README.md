# Tutur.id

Aplikasi interaktif pembelajaran BISINDO (Bahasa Isyarat Indonesia) dengan fitur inti latihan real-time menggunakan kamera dan on-device machine learning untuk mengenali gestur tangan pengguna secara langsung.

## Daftar Isi
- [Tentang Proyek](#tentang-proyek)
- [Tech Stack](#tech-stack)
- [Arsitektur Sistem](#arsitektur-sistem)
- [Fitur](#fitur)
- [Struktur Direktori](#struktur-direktori)
- [State Management (Riverpod)](#state-management-riverpod)
- [Environment Variables](#environment-variables)
- [Cara Setup](#cara-setup)
- [Model Machine Learning](#model-machine-learning)
- [Kontribusi](#kontribusi)

## Tentang Proyek

Tutur.id dibangun untuk membantu masyarakat umum mempelajari BISINDO secara mandiri dan interaktif, dengan validasi gerakan tangan secara real-time menggunakan model machine learning yang berjalan langsung di perangkat (on-device inference), tanpa bergantung pada koneksi server untuk proses pengenalan gestur.

Fokus utama pengembangan:
- **Stabilitas aplikasi** di berbagai perangkat.
- **Performa inference model** yang optimal (low-latency, tidak membebani UI thread).
- **Pengalaman belajar terstruktur** melalui sistem level dan modul progresif.

## Tech Stack

| Kategori | Teknologi |
|---|---|
| Framework | Flutter (mobile untuk pelajar, web untuk admin) |
| Backend as a Service | Firebase (Auth, Firestore, Realtime sync) |
| Media Storage | Cloudinary |
| Payment Gateway | Midtrans |
| Machine Learning | TensorFlow Lite + SSD MobileNet ([Patuli-ML](https://github.com/Patuli-Pahlawan-Tuli/Patuli-ML)) |
| State Management | Riverpod (`flutter_riverpod`, manual provider — tanpa code generation) |

## Arsitektur Sistem

User (Mobile) ──> Flutter App ──> Firebase (Auth, Sync, Notifikasi)
──> Cloudinary (Upload/Playback Media)
──> Midtrans (Transaksi & Status Pembayaran)
──> TFLite + SSD MobileNet (Input Frame → Inference Result)

Admin (Web/Browser) ──> Flutter App ──> Firebase / Midtrans (read & manage)


Model AI berjalan **on-device**, sehingga proses pengenalan gestur tidak memerlukan round-trip ke server — hanya hasil akhir (progres, XP, status baterai) yang disinkronkan ke Firebase.

### Alur Preprocessing → Inference

1. **Capture** — frame diambil dari kamera secara berkelanjutan (frame by frame).
2. **Preprocessing**:
   - Resize ke 320x320 px.
   - Normalisasi piksel (div 255.0) → rentang 0.0–1.0.
   - Channel adjustment → pastikan RGB murni (buang alpha channel).
   - Konversi ke `Float32List`.
3. **Inference** — data masuk ke input tensor TFLite, diproses oleh model SSD MobileNet di isolate terpisah.
4. **Output** — Bounding Box (posisi tangan) + Class Probability (kepercayaan gestur).
5. **Feedback** — indikator visual "Berhasil"/panduan koreksi ke pengguna.

## Fitur

### Pelajar
1. **Login & Onboarding** — SSO Google, lengkapi biodata (username, no. telp, foto profil/skippable), simpan ke Firebase.
2. **Akses Modul Belajar** — kategori materi terbagi level, konten via Cloudinary.
3. **Modul Belajar 3 Level**:
   - **Level 1 – First Steps**: Alphabet Alpha (A-M) + kuis 4 soal, Number Base (0-5) + kuis 3 soal, SpellingQuest I (filter input A-M & 0-4).
   - **Level 2 – Essential Skills**: Alphabet Omega (N-Z) + kuis 4 soal, Number Advance (6-10) + kuis 3 soal, The Identity challenge.
   - **Level 3 – Daily Conversation**: Social Essentials, Direction & Position, Expressive Signs (masing-masing + kuis), The Master Challenge (kalimat 3 kosakata acak).
4. **Latihan AI Kamera** — validasi real-time via SSD MobileNet, sistem baterai (2 poin/sesi, refresh rate per tier), sync real-time ke Firebase.
5. **Upgrade Subscription** — Starter (Rp0, 14 baterai, refresh 1/jam, Level 1-2), Growth (Rp35.000, 30 baterai, refresh 2/jam, semua level + badge), Ultimate (Rp75.000, unlimited baterai + fitur premium).
6. **Weekly Leaderboard & Gamifikasi** — XP otomatis (sesi +50, modul +100, kuis +10), 5 Daily Quest (reset 24 jam), leaderboard reset tiap Senin, visualisasi progres.
7. **Manage Profile** — edit data (kecuali email), lihat saldo baterai & riwayat aktivitas.
8. **Kirim Report & Feedback** — report (kategori AI/Pembayaran/Materi + 2 foto bukti), tombol WhatsApp untuk kendala mendesak, feedback (star rating + deskripsi).
9. **Pusat Notifikasi** — pesan sistem, reminder gamifikasi, status transaksi, arsip pesan.

### Admin
1. **Manajemen Pengguna** — monitor user aktif, status subscription, tindakan administratif.
2. **CRUD Materi Pembelajaran** — upload media ke Cloudinary, kelola deskripsi materi per level/modul.
3. **Broadcast Notifikasi** — custom messaging & automated templates.
4. **Laporan Transaksi Pembayaran** — riwayat Midtrans, pendapatan bulanan.
5. **Laporan Report & Feedback Pelajar** — filter by tipe/kategori, update status (Diterima/Diproses/Selesai) dengan pesan respon (template/custom), analisis star rating.

## Struktur Direktori
```
lib/
├── main.dart
├── app/
│ ├── app.dart # root widget, ProviderScope, routing setup
│ ├── router.dart
│ └── theme/
│ │ ├── colors.dart
│ │ └── text_styles.dart
│
├── core/
│ ├── constants/
│ ├── services/
│ │ ├── firebase_service.dart
│ │ ├── cloudinary_service.dart
│ │ ├── midtrans_service.dart
│ │ └── notification_service.dart
│ ├── network/
│ │ └── api_client.dart # Dio wrapper, dipakai Cloudinary & Midtrans service
│ ├── errors/
│ │ └── failure.dart
│ ├── utils/
│ └── widgets/ # reusable UI lintas fitur
│
├── features/
│ ├── auth/
│ │ ├── data/
│ │ │ ├── models/
│ │ │ └── repositories/
│ │ ├── logic/
│ │ └── presentation/
│ │ │ │ ├── screens/
│ │ │ │ └── widgets/
│ │
│ ├── learning/
│ │ ├── data/
│ │ ├── logic/
│ │ └── presentation/
│ │
│ ├── ai_training/ # fitur inti: kamera + TFLite
│ │ ├── data/
│ │ ├── logic/
│ │ ├── ml/
│ │ │ ├── preprocessing/ # resize, normalize, RGB convert
│ │ │ ├── inference/ # isolate untuk TFLite inference
│ │ │ └── model/ # loader .tflite + classes.txt
│ │ └── presentation/
│ │ ├── screens/
│ │ └── widgets/ # camera overlay, bounding box painter
│ │
│ ├── subscription/
│ ├── gamification/
│ ├── profile/
│ ├── feedback_report/
│ ├── notification/
│ │
│ └── admin/
│ ├── user_management/
│ ├── content_management/
│ ├── broadcast/
│ ├── transaction_report/
│ └── feedback_report_review/
│
└── shared/
│├── models/
│└── extensions/
│└── enums/
│└── validator/
```

Pola tiap fitur:
```
feature_x/
├── data/
│ ├── models/ # data class (fromJson/toJson), dipakai juga sebagai entity
│ └── repositories/ # implementasi konkret, ambil data dari core/services
├── logic/
│ └── feature_x_provider.dart # provider Riverpod (state + business logic)
└── presentation/
├── screens/ # halaman/page
└── widgets/ # komponen UI khusus fitur ini
```

Catatan desain:
- **Tanpa layer `domain/`** (tidak ada `entities/`, `repositories/` abstrak, `usecases/` terpisah) — disederhanakan karena skala proyek tidak membutuhkan full clean architecture.
- `data/repositories/` memanggil `core/services/` langsung, dan `logic/` memanggil `data/repositories/` langsung.
- `core/widgets/` untuk komponen lintas fitur, `features/*/presentation/widgets/` untuk komponen spesifik fitur tsb.

## State Management (Riverpod)

Menggunakan **manual provider** (bukan code generation) — provider ditulis langsung pakai constructor bawaan Riverpod.

Konvensi:
- Repository provider: `Provider<XRepository>` — stateless, cuma instance.
- Data fetching read-only: `FutureProvider` / `FutureProvider.family` (butuh parameter) / `StreamProvider` (real-time, misal battery status, leaderboard).
- Data dengan aksi/mutasi (submit form, proses inference, update baterai): `AsyncNotifier` / `AsyncNotifierProvider`.
- Gunakan `AsyncValue.when(data:, loading:, error:)` di UI — hindari boolean `isLoading` manual.
- Widget yang konsumsi provider extend `ConsumerWidget` / `ConsumerStatefulWidget`.

Contoh pattern dasar:
```dart
// data/repositories/learning_repository.dart
final learningRepositoryProvider = Provider<LearningRepository>((ref) {
  return LearningRepository(ref.watch(firebaseServiceProvider));
});

// logic/learning_provider.dart
final modulesProvider = FutureProvider.family<List<Module>, int>((ref, level) async {
  final repository = ref.watch(learningRepositoryProvider);
  return repository.getModules(level);
});

// presentation/screens/learning_screen.dart
class LearningScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulesAsync = ref.watch(modulesProvider(1));
    return modulesAsync.when(
      data: (modules) => ListView(
        children: modules.map((m) => ModuleCard(module: m)).toList(),
      ),
      loading: () => const CircularProgressIndicator(),
      error: (err, stack) => Text('Error: $err'),
    );
  }
}
```

Contoh pattern dengan aksi kompleks (`AsyncNotifier`) — dipakai misalnya di fitur AI training:
```dart
// features/ai_training/logic/ai_training_provider.dart
class AiTrainingNotifier extends AsyncNotifier<InferenceResult?> {
  @override
  Future<InferenceResult?> build() async => null;

  Future<void> processFrame(CameraImage frame) async {
    state = const AsyncLoading();
    final result = await ref.read(inferenceServiceProvider).run(frame);
    state = AsyncData(result);
  }
}

final aiTrainingProvider =
    AsyncNotifierProvider<AiTrainingNotifier, InferenceResult?>(
  AiTrainingNotifier.new,
);
```

## Environment Variables

Buat file `.env` di root project (jangan commit ke repo):

```
FIREBASE_API_KEY=
FIREBASE_PROJECT_ID=
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=
CLOUDINARY_API_SECRET=
MIDTRANS_SERVER_KEY=
MIDTRANS_CLIENT_KEY=
MIDTRANS_IS_PRODUCTION=false
```

## Cara Setup

```bash
# clone repo
git clone <repo-url>
cd tutur-id

# install dependencies
flutter pub get

# taruh file .tflite dan classes.txt dari Patuli-ML
# ke: assets/models/

# jalankan
flutter run
```

Pastikan `pubspec.yaml` mendaftarkan asset model:
```yaml
flutter:
  assets:
    - assets/models/model.tflite
    - assets/models/classes.txt
```

Bungkus root widget dengan `ProviderScope` (wajib untuk Riverpod):
```dart
void main() {
  runApp(const ProviderScope(child: MyApp()));
}
```

## Model Machine Learning

- Sumber: [Patuli-Pahlawan-Tuli/Patuli-ML](https://github.com/Patuli-Pahlawan-Tuli/Patuli-ML)
- Arsitektur: SSD MobileNet
- Format: `.tflite` + `classes.txt`
- Eksekusi: on-device via `tflite_flutter` (atau package sejenis), dijalankan di isolate terpisah agar tidak memblokir UI thread.
