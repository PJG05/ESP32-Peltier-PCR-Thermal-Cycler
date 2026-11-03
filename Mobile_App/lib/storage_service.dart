import 'package:hive_flutter/hive_flutter.dart';

import '../models/pcr_program.dart';

class StorageService {
  static const String boxName = "pcrPrograms";

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(boxName);
  }

  static Box get _box => Hive.box(boxName);

  /// Save a PCR Program
  static Future<void> saveProgram(PCRProgram program) async {
    await _box.add(program.toMap());
  }

  /// Get all saved programs
  static List<PCRProgram> getPrograms() {
    return _box.values
        .map(
          (e) => PCRProgram.fromMap(
        Map<String, dynamic>.from(e),
      ),
    )
        .toList();
  }

  /// Update an existing program
  static Future<void> updateProgram(
      int index,
      PCRProgram program,
      ) async {
    await _box.putAt(index, program.toMap());
  }

  /// Delete a program
  static Future<void> deleteProgram(int index) async {
    await _box.deleteAt(index);
  }

  /// Delete every saved protocol
  static Future<void> clearAllPrograms() async {
    await _box.clear();
  }

  /// Number of stored programs
  static int get programCount => _box.length;
}