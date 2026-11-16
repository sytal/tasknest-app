/// Form validation rules. Keep in sync with the Laravel FormRequests.
class Validators {
  static const int passwordMin = 8;
  static const int titleMax = 255;
  static const int nameMax = 255;
  static const int descriptionMax = 5000;
  static const int projectDescriptionMax = 2000;
  static const int commentMax = 2000;
  static const int labelMax = 30;

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static String? required(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '$label is required' : null;

  static String? maxLen(String? v, int max, String label) =>
      (v != null && v.trim().length > max)
      ? '$label must be at most $max characters'
      : null;

  static String? requiredMax(String? v, String label, int max) =>
      required(v, label) ?? maxLen(v, max, label);

  static String? email(String? v) {
    final r = required(v, 'Email');
    if (r != null) return r;
    final t = v!.trim();
    if (t.length > 255) return 'Email must be at most 255 characters';
    return _email.hasMatch(t) ? null : 'Enter a valid email address';
  }

  static String? newPassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < passwordMin) {
      return 'Use at least $passwordMin characters';
    }
    return null;
  }
}
