Data testing kamu ini sangat membantu — sekarang kita punya angka konkret buat ambil keputusan, bukan cuma asumsi. Aku bedah dulu, baru masuk ke solusi.

## Analisis Data Kamu

**Soal Latency:**
- Rata-rata inference: **65-107ms** per frame (di Python/desktop, pakai XNNPACK delegate CPU).
- Ini **bukan** angka yang buruk untuk sekali inference — tapi masalahnya seperti dugaan kamu: kalau ini dipanggil **terus-menerus tiap frame** dari camera stream (biasanya 30 FPS = tiap ~33ms), otomatis device gak akan pernah selesai proses satu frame sebelum frame berikutnya masuk. Inference queue menumpuk → beban naik terus → app freeze/lag.
- Catatan penting: **latency di HP (ARM, mobile CPU) kemungkinan besar lebih lambat** dari hasil testing Python di laptop kamu (kemungkinan CPU AMD Ryzen kamu jauh lebih kuat dari CPU HP kelas menengah). Jadi 65-107ms ini kemungkinan **best case**, bukan representasi asli di device target.

**Soal Confidence Threshold:**
- Semua hasil testing kamu confidence-nya **90%+** (bahkan kebanyakan 96-99%) — jadi menaikkan threshold dari 0.20 ke 0.40-0.50 **aman** dan justru bagus, karena akan otomatis membuang deteksi noise/false positive tanpa mengorbankan deteksi yang benar.
- Contoh kasus di `image_laki_laki.jpg` — ada 2 deteksi: "Laki-laki" (90.49%) dan "Kanan" (20.65%). Deteksi kedua ini **jelas noise**, dan dengan threshold 0.20 dia ikut lolos. Kalau dinaikkan ke 0.40+, otomatis ke-filter.

## Soal Ide Cooldown Kamu — Ini Solusi yang Tepat

Pendekatan kamu **benar secara arsitektur**, dan ini sebenarnya adalah pola umum yang dipakai di aplikasi computer vision mobile (bukan cuma solusi darurat) — namanya **"throttled/debounced inference"**. Beberapa alasan kenapa ini pilihan yang solid:

1. **Realistis untuk use case fingerspelling/gesture** — user butuh waktu untuk membentuk gestur tangan dengan benar, jadi gak masuk akal juga kalau sistem coba deteksi 30x per detik. Manusia gak gerak secepat itu.
2. **UX lebih jelas** — dengan sistem cooldown + visual feedback (misal countdown ring), user tahu kapan harus "siap-siap" dan kapan sistem "mengambil gambar", mirip UX kamera foto dengan timer.
3. **Battery & thermal lebih aman** — penting banget karena device kamu (dan kemungkinan besar device pengguna nanti) bukan flagship dengan NPU khusus.

## Refinement Ide Kamu

Sedikit penyesuaian dari yang kamu usulkan, supaya UX-nya lebih baik:

### Alih-alih Cooldown Fixed 3 Detik, Pakai State Machine

```
IDLE → user siapkan tangan di frame
  ↓ (user tap tombol "Deteksi" ATAU otomatis countdown 3 detik)
CAPTURING → ambil 1 frame, jalankan inference
  ↓
PROCESSING → tampilkan loading indicator (durasi ~100-300ms di HP asli)
  ↓
RESULT → tampilkan hasil (benar/salah), lalu balik ke IDLE
```

Kenapa gak murni auto-cooldown tanpa kontrol user? Karena kalau user **belum siap** posisinya pas cooldown habis, sistem tetap capture frame yang salah — buang-buang inference cycle. Jadi aku sarankan **kombinasi**: ada tombol manual "Coba Sekarang" **plus** auto-trigger tiap beberapa detik sebagai fallback, mana yang duluan terjadi.

### Implementasi

```dart
// lib/features/ai_training/logic/ai_training_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';

enum DetectionState { idle, capturing, processing, result }

class InferenceResult {
  final String label;
  final double confidence;
  final bool isCorrect; // dibandingkan dengan target huruf/kata yang diharapkan

  InferenceResult({
    required this.label,
    required this.confidence,
    required this.isCorrect,
  });
}

class AiTrainingState {
  final DetectionState detectionState;
  final InferenceResult? lastResult;
  final int cooldownSecondsLeft;

  AiTrainingState({
    this.detectionState = DetectionState.idle,
    this.lastResult,
    this.cooldownSecondsLeft = 0,
  });

  AiTrainingState copyWith({
    DetectionState? detectionState,
    InferenceResult? lastResult,
    int? cooldownSecondsLeft,
  }) {
    return AiTrainingState(
      detectionState: detectionState ?? this.detectionState,
      lastResult: lastResult ?? this.lastResult,
      cooldownSecondsLeft: cooldownSecondsLeft ?? this.cooldownSecondsLeft,
    );
  }
}

class AiTrainingNotifier extends Notifier<AiTrainingState> {
  Timer? _cooldownTimer;
  static const int _cooldownDuration = 3; // detik, sesuai usul kamu

  @override
  AiTrainingState build() {
    ref.onDispose(() => _cooldownTimer?.cancel());
    return AiTrainingState();
  }

  void startCooldown() {
    if (state.detectionState != DetectionState.idle) return;

    state = state.copyWith(cooldownSecondsLeft: _cooldownDuration);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = state.cooldownSecondsLeft - 1;
      if (remaining <= 0) {
        timer.cancel();
        triggerDetection();
      } else {
        state = state.copyWith(cooldownSecondsLeft: remaining);
      }
    });
  }

  Future<void> triggerDetection({CameraImage? frame}) async {
    _cooldownTimer?.cancel();
    state = state.copyWith(detectionState: DetectionState.capturing);

    // beri jeda kecil biar UI "capturing" sempat tampil
    await Future.delayed(const Duration(milliseconds: 150));

    state = state.copyWith(detectionState: DetectionState.processing);

    // TODO: panggil inference service di sini (isolate)
    // final result = await ref.read(inferenceServiceProvider).run(frame);

    // Simulasi sementara sampai inference service dibuat:
    await Future.delayed(const Duration(milliseconds: 200));

    state = state.copyWith(
      detectionState: DetectionState.result,
      // lastResult: result,
    );
  }

  void reset() {
    _cooldownTimer?.cancel();
    state = AiTrainingState(); // balik ke idle
  }
}

final aiTrainingProvider = NotifierProvider<AiTrainingNotifier, AiTrainingState>(
  AiTrainingNotifier.new,
);
```

### UI dengan Placeholder Deteksi & Cooldown Indicator

```dart
// lib/features/ai_training/presentation/screens/ai_training_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../logic/ai_training_provider.dart';

class AiTrainingScreen extends ConsumerStatefulWidget {
  final String moduleId;
  const AiTrainingScreen({super.key, required this.moduleId});

  @override
  ConsumerState<AiTrainingScreen> createState() => _AiTrainingScreenState();
}

class _AiTrainingScreenState extends ConsumerState<AiTrainingScreen> {
  @override
  void initState() {
    super.initState();
    // TODO: init CameraController di sini
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiTrainingProvider);
    final notifier = ref.read(aiTrainingProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Latihan Kamera')),
      body: Stack(
        children: [
          // TODO: ganti dengan CameraPreview asli
          Container(color: Colors.black87),

          // Placeholder target area di tengah - sesuai usul kamu
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _borderColorFor(state.detectionState),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: state.detectionState == DetectionState.processing
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : null,
            ),
          ),

          // Cooldown countdown indicator
          if (state.cooldownSecondsLeft > 0)
            Positioned(
              top: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Bersiap... ${state.cooldownSecondsLeft}',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ),

          // Hasil deteksi
          if (state.detectionState == DetectionState.result && state.lastResult != null)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: state.lastResult!.isCorrect ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    state.lastResult!.isCorrect
                        ? '✓ Benar! (${state.lastResult!.label})'
                        : '✗ Coba lagi (terdeteksi: ${state.lastResult!.label})',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ),

          // Tombol kontrol
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: _buildActionButton(state, notifier),
            ),
          ),
        ],
      ),
    );
  }

  Color _borderColorFor(DetectionState state) {
    switch (state) {
      case DetectionState.idle:
        return Colors.white54;
      case DetectionState.capturing:
      case DetectionState.processing:
        return Colors.orange;
      case DetectionState.result:
        return Colors.green;
    }
  }

  Widget _buildActionButton(AiTrainingState state, AiTrainingNotifier notifier) {
    switch (state.detectionState) {
      case DetectionState.idle:
        return ElevatedButton.icon(
          onPressed: notifier.startCooldown,
          icon: const Icon(Icons.camera),
          label: const Text('Mulai Deteksi'),
        );
      case DetectionState.result:
        return ElevatedButton.icon(
          onPressed: notifier.reset,
          icon: const Icon(Icons.refresh),
          label: const Text('Coba Lagi'),
        );
      default:
        return const SizedBox.shrink(); // gak ada tombol saat capturing/processing
    }
  }
}
```

## Ringkasan Keputusan Teknis

| Keputusan | Alasan |
|---|---|
| Confidence threshold **0.40-0.50** | Data testing kamu nunjukkin semua deteksi valid ada di atas 90%, aman dinaikkan untuk filter noise |
| Cooldown 3 detik + manual trigger | Sesuai usulan kamu, dilengkapi kontrol manual biar user gak "kecolongan" waktu capture |
| Inference dipanggil **sekali per trigger**, bukan per frame | Ini inti solusi kamu — drastis mengurangi beban dibanding continuous inference |
| State machine (idle → capturing → processing → result) | Supaya UI jelas dan user paham kapan harus diam vs kapan hasil muncul |

## Yang Masih Perlu Kamu Putuskan

1. **Auto-trigger vs manual-only** — barusan aku desain hybrid (ada cooldown otomatis + tombol manual). Kalau kamu mau **manual-only dulu** (user tekan tombol tiap kali mau dites, gak ada auto-countdown), itu lebih simpel diimplementasi dan lebih gampang dites — cooldown bisa ditambahkan belakangan sebagai enhancement. Mana yang kamu mau duluan?
2. **Preprocessing pipeline** (resize 320x320, normalize, dst) belum aku buat kodenya — itu next step setelah struktur capture-trigger ini kamu setujui.
3. Confidence threshold final — mau langsung set 0.40 atau 0.50? Aku sarankan mulai dari **0.40**, karena kalau nanti device pengguna asli kualitas kameranya lebih rendah dari testing kamu (pencahayaan, resolusi), confidence bisa turun dibanding hasil test kamu barusan.

Gimana, mau lanjut manual-only dulu atau langsung pakai versi hybrid (cooldown + manual) yang aku buat ini?

Ide ini bagus dan lebih clean dari yang aku desain sebelumnya — karena kamu ganti dari "auto-cooldown otomatis" jadi "**shutter timer setelah user aktif klik**", ini beberapa keuntungannya:

## Kenapa Pendekatan Ini Lebih Baik

1. **User punya kontrol penuh kapan mulai** — beda dengan versi aku sebelumnya yang auto-trigger tiap 3 detik terus-menerus, ini user yang inisiasi, jadi gak ada "kejutan" capture pas belum siap.
2. **Mental model familiar** — orang udah paham konsep "timer kamera" dari pengalaman foto selfie sehari-hari, jadi gak perlu belajar UX baru.
3. **Single inference call per klik** — jelas dan predictable, gampang di-debug kalau ada masalah performa, karena kamu tahu persis kapan inference terjadi (gak ada logic cooldown otomatis yang jalan di background).
4. **Popup hasil lebih tegas** daripada inline banner — user gak akan miss hasilnya, apalagi kalau posisi tangan mereka nutupin area banner di layar sebelumnya.

## Refinement Kecil

Cuma 2 penyesuaian dari idemu:

1. **Tampilkan angka countdown besar di tengah** (4, 3, 2, 1) — biar user tau kapan tepatnya harus "freeze" posisi tangan, bukan cuma teks kecil.
2. **Popup pakai `AlertDialog`**, dengan tombol "Coba Lagi" langsung di dalamnya — biar alurnya: klik tombol → countdown → capture → popup hasil → user bisa langsung klik "Coba Lagi" tanpa perlu cari tombol lain.

## Implementasi

### State & Notifier

```dart
// lib/features/ai_training/logic/ai_training_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DetectionState { idle, countdown, processing, result }

class InferenceResult {
  final String label;
  final double confidence;
  final bool isCorrect;

  InferenceResult({
    required this.label,
    required this.confidence,
    required this.isCorrect,
  });
}

class AiTrainingState {
  final DetectionState detectionState;
  final int countdownValue;
  final InferenceResult? lastResult;

  AiTrainingState({
    this.detectionState = DetectionState.idle,
    this.countdownValue = 0,
    this.lastResult,
  });

  AiTrainingState copyWith({
    DetectionState? detectionState,
    int? countdownValue,
    InferenceResult? lastResult,
  }) {
    return AiTrainingState(
      detectionState: detectionState ?? this.detectionState,
      countdownValue: countdownValue ?? this.countdownValue,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

class AiTrainingNotifier extends Notifier<AiTrainingState> {
  Timer? _timer;
  static const int _shutterDuration = 4; // sesuai ide kamu

  @override
  AiTrainingState build() {
    ref.onDispose(() => _timer?.cancel());
    return AiTrainingState();
  }

  void startShutterTimer({required String expectedLabel}) {
    if (state.detectionState != DetectionState.idle) return;

    state = state.copyWith(
      detectionState: DetectionState.countdown,
      countdownValue: _shutterDuration,
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = state.countdownValue - 1;
      if (remaining <= 0) {
        timer.cancel();
        _runInference(expectedLabel: expectedLabel);
      } else {
        state = state.copyWith(countdownValue: remaining);
      }
    });
  }

  Future<void> _runInference({required String expectedLabel}) async {
    state = state.copyWith(detectionState: DetectionState.processing);

    // TODO: ganti dengan pemanggilan inference service asli (isolate)
    // final result = await ref.read(inferenceServiceProvider).run(frame);

    // Simulasi sementara
    await Future.delayed(const Duration(milliseconds: 300));
    final result = InferenceResult(
      label: expectedLabel, // dummy, nanti diganti hasil model asli
      confidence: 0.95,
      isCorrect: true,
    );

    state = state.copyWith(
      detectionState: DetectionState.result,
      lastResult: result,
    );
  }

  void reset() {
    _timer?.cancel();
    state = AiTrainingState();
  }
}

final aiTrainingProvider = NotifierProvider<AiTrainingNotifier, AiTrainingState>(
  AiTrainingNotifier.new,
);
```

### UI dengan Countdown Overlay + Popup Hasil

```dart
// lib/features/ai_training/presentation/screens/ai_training_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../logic/ai_training_provider.dart';

class AiTrainingScreen extends ConsumerStatefulWidget {
  final String moduleId;
  final String expectedLabel; // huruf/angka/kata yang harus diperagakan

  const AiTrainingScreen({
    super.key,
    required this.moduleId,
    required this.expectedLabel,
  });

  @override
  ConsumerState<AiTrainingScreen> createState() => _AiTrainingScreenState();
}

class _AiTrainingScreenState extends ConsumerState<AiTrainingScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiTrainingProvider);
    final notifier = ref.read(aiTrainingProvider.notifier);

    // Trigger popup begitu hasil muncul
    ref.listen(aiTrainingProvider, (previous, next) {
      if (next.detectionState == DetectionState.result && next.lastResult != null) {
        _showResultDialog(context, next.lastResult!, notifier);
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text('Peragakan: ${widget.expectedLabel}')),
      body: Stack(
        children: [
          // TODO: ganti dengan CameraPreview asli
          Container(color: Colors.black87),

          // Target area di tengah
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _borderColorFor(state.detectionState),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: state.detectionState == DetectionState.processing
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : null,
            ),
          ),

          // Countdown angka besar di tengah - shutter timer style
          if (state.detectionState == DetectionState.countdown)
            Center(
              child: Text(
                '${state.countdownValue}',
                style: const TextStyle(
                  fontSize: 96,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [Shadow(blurRadius: 12, color: Colors.black)],
                ),
              ),
            ),

          // Instruksi
          Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                _instructionText(state.detectionState),
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),

          // Tombol mulai
          if (state.detectionState == DetectionState.idle)
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: () => notifier.startShutterTimer(
                    expectedLabel: widget.expectedLabel,
                  ),
                  icon: const Icon(Icons.camera),
                  label: const Text('Mulai (4 detik)'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _instructionText(DetectionState state) {
    switch (state) {
      case DetectionState.idle:
        return 'Posisikan tanganmu di dalam kotak, lalu klik mulai';
      case DetectionState.countdown:
        return 'Bersiap...';
      case DetectionState.processing:
        return 'Menganalisa...';
      case DetectionState.result:
        return '';
    }
  }

  Color _borderColorFor(DetectionState state) {
    switch (state) {
      case DetectionState.idle:
        return Colors.white54;
      case DetectionState.countdown:
        return Colors.orange;
      case DetectionState.processing:
        return Colors.blue;
      case DetectionState.result:
        return Colors.green;
    }
  }

  void _showResultDialog(
    BuildContext context,
    InferenceResult result,
    AiTrainingNotifier notifier,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(
          result.isCorrect ? Icons.check_circle : Icons.cancel,
          color: result.isCorrect ? Colors.green : Colors.red,
          size: 48,
        ),
        title: Text(result.isCorrect ? 'Benar!' : 'Coba Lagi'),
        content: Text(
          result.isCorrect
              ? 'Jawabannya adalah "${result.label}"'
              : 'Terdeteksi sebagai "${result.label}", bukan "${widget.expectedLabel}"',
        ),
        actions: [
          if (!result.isCorrect)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                notifier.reset();
              },
              child: const Text('Coba Lagi'),
            ),
          if (result.isCorrect)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // kembali ke screen sebelumnya
                // TODO: trigger completeModule / lanjut ke huruf berikutnya
              },
              child: const Text('Lanjut'),
            ),
        ],
      ),
    );
  }
}
```

## Poin Penting yang Perlu Diputuskan

1. **`expectedLabel` datang dari mana?** Ini parameter yang kamu kirim ke screen ini — misal dari `ModuleDetailScreen`, tiap `MaterialItem` (huruf "A", "B", dst) akan navigate ke `AiTrainingScreen` dengan `expectedLabel` sesuai huruf yang lagi dipelajari. Perlu aku update alur navigasi dari `ModuleDetailScreen` supaya connect ke sini?

2. **Kalau salah, apakah retry pakai sisa attempt terbatas atau bebas coba terus?** Saat ini didesain **bebas coba berkali-kali** (klik "Coba Lagi" → balik ke idle → bisa mulai timer lagi). Ini konsisten sama requirement awal kamu soal "Umpan Balik Sistem" yang bilang kalau salah kasih panduan tambahan, gak disebutkan ada limit percobaan.

3. **Baterai berkurang di titik mana?** Sesuai requirement awal ("Setiap sesi latihan yang menggunakan pemindaian kamera akan mengonsumsi 2 poin baterai"), perlu diputuskan: baterai berkurang **per klik "Mulai"** (tiap kali shutter jalan), atau **per sesi masuk ke screen ini** (sekali aja walau coba berkali-kali)? Ini penting karena mempengaruhi UX — kalau per klik, user mungkin ragu-ragu coba karena takut boros baterai.

Gimana soal 3 poin itu, dan apakah struktur popup + countdown ini udah sesuai bayangan kamu?

Oke, aku putuskan berdasarkan konteks yang udah jelas:

## 1. `expectedLabel` — Sumbernya dari Mana

Aku sarankan alurnya begini:

```
ModuleDetailScreen (list huruf: A, B, C...)
   ↓ user tap salah satu MaterialItem, misal huruf "A"
AiTrainingScreen(expectedLabel: "A", moduleId: ..., materialId: ...)
   ↓ setelah berhasil (isCorrect true), klik "Lanjut"
   → otomatis pindah ke huruf berikutnya dalam modul yang sama (misal "B")
   → atau kalau itu huruf terakhir, balik ke ModuleDetailScreen
```

Supaya ini jalan, `AiTrainingScreen` butuh tau **posisi huruf saat ini dalam list materials**, bukan cuma satu label statis. Aku update parameternya:

```dart
class AiTrainingScreen extends ConsumerStatefulWidget {
  final String moduleId;
  final List<MaterialItem> materials; // seluruh list huruf/angka dalam modul ini
  final int currentIndex; // posisi huruf yang sedang dipelajari

  const AiTrainingScreen({
    super.key,
    required this.moduleId,
    required this.materials,
    required this.currentIndex,
  });

  MaterialItem get currentMaterial => materials[currentIndex];
  bool get isLastMaterial => currentIndex >= materials.length - 1;
}
```

Waktu klik "Lanjut" di popup hasil benar:
```dart
ElevatedButton(
  onPressed: () {
    Navigator.pop(context); // tutup dialog
    if (widget.isLastMaterial) {
      context.pop(); // balik ke ModuleDetailScreen, modul selesai
      // TODO: trigger completeModule di sini
    } else {
      // ganti ke huruf berikutnya, TANPA navigasi baru - cukup update state
      ref.read(aiTrainingProvider.notifier).reset();
      setState(() {
        _currentIndex++; // pindah ke index berikutnya dalam list yang sama
      });
    }
  },
  child: const Text('Lanjut'),
),
```

Ini lebih efisien daripada navigate ke screen baru tiap huruf — cukup update index di screen yang sama, camera preview juga gak perlu di-reinit tiap ganti huruf.

## 2. Retry Tanpa Batas — Sudah Sesuai Desain Sebelumnya

Bagus, ini memang sudah cocok sama kode yang aku buat kemarin (`notifier.reset()` balik ke idle, user bisa klik "Mulai" lagi kapan saja). Gak perlu diubah.

## 3. Baterai Dipotong Sekali di Awal Sesi — Ini Keputusan yang Tepat

Setuju sama alasan kamu — kalau dipotong tiap klik tombol "Mulai" (shutter), user jadi takut nyoba berkali-kali padahal justru itu inti dari proses belajar (trial & error). Baterai dipotong **sekali** pas pertama kali masuk ke `AiTrainingScreen` untuk satu modul, bukan per attempt.

Konsekuensinya: **1 modul = 1 kali potong baterai**, walaupun di dalamnya ada banyak huruf (misal Alphabet Alpha punya 13 huruf) dan user boleh retry sepuasnya di tiap huruf tanpa potongan tambahan.

### Implementasi

```dart
// features/ai_training/logic/ai_training_provider.dart

class AiTrainingNotifier extends Notifier<AiTrainingState> {
  Timer? _timer;
  static const int _shutterDuration = 4;

  @override
  AiTrainingState build() {
    ref.onDispose(() => _timer?.cancel());
    return AiTrainingState();
  }

  // Dipanggil SEKALI saat AiTrainingScreen pertama kali dibuka untuk modul ini
  Future<bool> startSession() async {
    final profile = await ref.read(userProfileProvider.future);
    if (profile == null) return false;

    if (profile.battery < 2) {
      return false; // baterai gak cukup, screen harus tampilkan warning
    }

    // Potong baterai 2 poin, sekali per sesi
    await ref.read(batteryRepositoryProvider).consumeBattery(profile.uid, 2);
    ref.invalidate(userProfileProvider);
    return true;
  }

  void startShutterTimer({required String expectedLabel}) {
    // tetap sama seperti sebelumnya - TIDAK ada potongan baterai di sini
    if (state.detectionState != DetectionState.idle) return;
    state = state.copyWith(
      detectionState: DetectionState.countdown,
      countdownValue: _shutterDuration,
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = state.countdownValue - 1;
      if (remaining <= 0) {
        timer.cancel();
        _runInference(expectedLabel: expectedLabel);
      } else {
        state = state.copyWith(countdownValue: remaining);
      }
    });
  }

  // ... _runInference dan reset() tetap sama
}
```

### Update Screen: Cek & Potong Baterai di `initState`

```dart
class _AiTrainingScreenState extends ConsumerState<AiTrainingScreen> {
  bool _sessionStarted = false;
  bool _insufficientBattery = false;

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  Future<void> _initSession() async {
    final success = await ref.read(aiTrainingProvider.notifier).startSession();
    setState(() {
      _sessionStarted = success;
      _insufficientBattery = !success;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_insufficientBattery) {
      return Scaffold(
        appBar: AppBar(title: const Text('Latihan Kamera')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.battery_alert, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text('Baterai tidak cukup untuk memulai sesi latihan'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.push('/subscription'),
                child: const Text('Upgrade untuk Baterai Lebih Banyak'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_sessionStarted) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ... UI utama seperti sebelumnya (camera, countdown, dst)
  }
}
```

### Perlu Ditambahkan: `BatteryRepository`

```dart
// lib/features/ai_training/data/repositories/battery_repository.dart
import '../../../../core/services/firebase_service.dart';

class BatteryRepository {
  final FirebaseService _firebaseService;
  BatteryRepository(this._firebaseService);

  Future<void> consumeBattery(String userId, int amount) async {
    final userData = await _firebaseService.getDocument('users', userId);
    final currentBattery = userData?['battery'] as int? ?? 0;
    final newBattery = (currentBattery - amount).clamp(0, 999);

    await _firebaseService.updateDocument('users', userId, {
      'battery': newBattery,
    });
  }

  Future<void> refillBattery(String userId, int amount, int maxCapacity) async {
    final userData = await _firebaseService.getDocument('users', userId);
    final currentBattery = userData?['battery'] as int? ?? 0;
    final newBattery = (currentBattery + amount).clamp(0, maxCapacity);

    await _firebaseService.updateDocument('users', userId, {
      'battery': newBattery,
    });
  }
}

final batteryRepositoryProvider = Provider<BatteryRepository>((ref) {
  return BatteryRepository(ref.watch(firebaseServiceProvider));
});
```

## Yang Masih Perlu Didiskusikan: Battery Refresh Otomatis

Sesuai requirement awal, ada mekanisme **refresh rate** (misal Starter: 1 baterai/jam). Ini butuh logic terpisah — biasanya dihitung berdasarkan **timestamp terakhir refill** dibanding waktu sekarang, dihitung setiap kali user buka app (bukan pakai background job/cron yang rumit untuk skala skripsi). Ini bisa kita bahas detailnya setelah alur inti `ai_training/` ini beres, karena sifatnya independent — gak menghalangi progress sekarang.

## Ringkasan Keputusan Final

| Aspek | Keputusan |
|---|---|
| Trigger deteksi | Manual klik "Mulai" → shutter timer 4 detik → capture sekali |
| Retry setelah salah | Bebas tanpa batas, tanpa potongan baterai tambahan |
| Potongan baterai | **Sekali di awal sesi** (saat `AiTrainingScreen` dibuka untuk 1 modul), bukan per attempt |
| Navigasi antar huruf dalam 1 modul | Update state index, bukan navigate screen baru — camera tetap aktif |
| Baterai gak cukup | Screen tampilkan pesan + CTA ke halaman subscription |

Semua ini udah align. Lanjut ke bagian **preprocessing pipeline** (resize 320x320, normalize, RGB convert) dan **isolate untuk inference**, atau ada yang mau disesuaikan dulu dari desain di atas?
