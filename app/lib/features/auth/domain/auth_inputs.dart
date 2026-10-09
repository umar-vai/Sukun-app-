String? validateSignInIdentifier(String? value) {
  final normalized = value?.trim() ?? '';
  if (normalized.length < 3 || normalized.length > 160) {
    return 'Enter your patient ID, phone number, or admin email.';
  }
  return null;
}

String? validateRegistrationEmail(String? value) {
  final normalized = value?.trim() ?? '';
  if (normalized.isEmpty ||
      normalized.length > 254 ||
      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalized)) {
    return 'একটি সঠিক ইমেইল ঠিকানা লিখুন।';
  }
  return null;
}

String? validateAccountPassword(String? value) {
  final length = value?.length ?? 0;
  if (length < 8 || length > 72) return 'Use 8–72 characters.';
  return null;
}

String? validateConfirmedPassword(String value, String confirmation) {
  final validation = validateAccountPassword(value);
  if (validation != null) return validation;
  if (value != confirmation) return 'The passwords do not match.';
  return null;
}
