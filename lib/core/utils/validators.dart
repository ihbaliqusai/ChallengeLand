class Validators {
  const Validators._();

  static String? username(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 3) return 'اسم اللاعب يجب أن يكون 3 أحرف على الأقل';
    if (text.length > 20) return 'اسم اللاعب طويل جدًا';
    return null;
  }

  static String? roomCode(String? value) {
    final text = value?.trim().toUpperCase() ?? '';
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(text)) {
      return 'أدخل كود غرفة صحيح من 6 خانات';
    }
    return null;
  }
}
