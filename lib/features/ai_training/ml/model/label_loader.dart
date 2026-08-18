import 'package:flutter/services.dart';

class LabelLoader {
  static Future<List<String>> loadLabels(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath); // jadi string literal
    return raw
        .split('\n') // split berdasarkan enter '\n'
        .map((line) => line.trim()) // mapping lagi lalu trim biar gada spasi
        .where((line) => line.isNotEmpty) // kalo string itu null atau empty skip
        .toList(); // convert jadi list
  }
}
