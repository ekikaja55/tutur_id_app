// note : Ai training screen kan cuma bisa nampung 1 model padahal sesi spelling quest
// & the identity( latihan modul) itu perlu lebih dari 1 model jadi pakai resolve buat bantu nentuin pakai
// model yang mana saat sesi latihan

import 'package:tutur_id_app/shared/enums/model_category.dart';

class ModelCategoryResolver {
  static ModelCategory resolve(String label) {
    // angka
    if (RegExp(r'^[0-9]+$').hasMatch(label)) {
      return ModelCategory.number;
    }

    // 1 huruf tunggal
    if (label.length == 1 && RegExp(r'^[A-Za-z]$').hasMatch(label)) {
      return ModelCategory.alphabet;
    }

    // selain itu semua berarti huruf jamak (kata)
    return ModelCategory.words;
  }
}
