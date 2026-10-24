import 'dart:convert';
import 'dart:io';

void main() {
  final mainFile = File('assets/questions.json');
  if (!mainFile.existsSync()) {
    print("Error: assets/questions.json not found!");
    exit(1);
  }

  final backupFile = File('assets/questions.backup_before_bab_alhara.json');
  if (!backupFile.existsSync()) {
    mainFile.copySync(backupFile.path);
    print("Created backup at: ${backupFile.path}");
  }

  final mainContent = mainFile.readAsStringSync(encoding: utf8);
  final List<dynamic> mainQuestions = jsonDecode(mainContent);
  print("Current questions in questions.json: ${mainQuestions.length}");

  final newFile = File('assets/questions_bab_alhara_300.json');
  if (!newFile.existsSync()) {
    print("Error: assets/questions_bab_alhara_300.json not found!");
    exit(1);
  }

  final newContent = newFile.readAsStringSync(encoding: utf8);
  final List<dynamic> newQuestions = jsonDecode(newContent);
  print("New questions to add: ${newQuestions.length}");

  // Remove any existing questions with category 'باب الحارة' for idempotency
  final filtered = mainQuestions.where((q) {
    final cat = q['Category']?.toString().trim();
    return cat != 'باب الحارة';
  }).toList();

  final removedCount = mainQuestions.length - filtered.length;
  if (removedCount > 0) {
    print("Removed $removedCount existing 'باب الحارة' questions for clean merge.");
  }

  filtered.addAll(newQuestions);
  print("Updated total questions count: ${filtered.length}");

  // Write back to assets/questions.json
  final updatedJson = JsonEncoder.withIndent("  ").convert(filtered);
  mainFile.writeAsStringSync(updatedJson, encoding: utf8);
  print("Successfully updated assets/questions.json!");
}
