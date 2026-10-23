import 'dart:convert';
import 'dart:io';

void main() {
  final mainFile = File('assets/questions.json');
  if (!mainFile.existsSync()) {
    print("Error: assets/questions.json not found!");
    exit(1);
  }

  final backupFile = File('assets/questions.backup_before_players.json');
  if (!backupFile.existsSync()) {
    mainFile.copySync(backupFile.path);
    print("Created backup at: ${backupFile.path}");
  }

  final mainContent = mainFile.readAsStringSync(encoding: utf8);
  final List<dynamic> mainQuestions = jsonDecode(mainContent);
  print("Current questions in questions.json: ${mainQuestions.length}");

  final newFile = File('assets/questions_career_300.json');
  if (!newFile.existsSync()) {
    print("Error: assets/questions_career_300.json not found!");
    exit(1);
  }

  final newContent = newFile.readAsStringSync(encoding: utf8);
  final List<dynamic> newQuestions = jsonDecode(newContent);
  print("New questions to add: ${newQuestions.length}");

  // Remove any previously added questions with category 'لاعبين كرة قدم' or 'مسيرة لاعب' to allow idempotency
  final filtered = mainQuestions.where((q) {
    final cat = q['Category']?.toString().trim();
    return cat != 'لاعبين كرة قدم' && cat != 'مسيرة لاعب';
  }).toList();

  final removedCount = mainQuestions.length - filtered.length;
  if (removedCount > 0) {
    print("Removed $removedCount existing 'لاعبين كرة قدم' / 'مسيرة لاعب' questions for clean merge.");
  }

  filtered.addAll(newQuestions);
  print("Updated total questions count: ${filtered.length}");

  // Write back to assets/questions.json
  final updatedJson = JsonEncoder.withIndent("  ").convert(filtered);
  mainFile.writeAsStringSync(updatedJson, encoding: utf8);
  print("Successfully updated assets/questions.json!");
}
