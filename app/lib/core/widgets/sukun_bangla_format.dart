/// Display-only Bangla formatting helpers that do not depend on Intl locale
/// initialization, so they render identically on every device and in tests.
library;

const _banglaDigits = '০১২৩৪৫৬৭৮৯';

const _banglaWeekdays = [
  'সোমবার',
  'মঙ্গলবার',
  'বুধবার',
  'বৃহস্পতিবার',
  'শুক্রবার',
  'শনিবার',
  'রবিবার',
];

const _banglaMonths = [
  'জানুয়ারি',
  'ফেব্রুয়ারি',
  'মার্চ',
  'এপ্রিল',
  'মে',
  'জুন',
  'জুলাই',
  'আগস্ট',
  'সেপ্টেম্বর',
  'অক্টোবর',
  'নভেম্বর',
  'ডিসেম্বর',
];

String banglaDigits(Object value) => value.toString().replaceAllMapped(
  RegExp(r'[0-9]'),
  (match) => _banglaDigits[int.parse(match.group(0)!)],
);

/// e.g. "সোমবার, ২ নভেম্বর"
String banglaWeekdayDate(DateTime date) => banglaDigits(
  '${_banglaWeekdays[date.weekday - 1]}, ${date.day} ${_banglaMonths[date.month - 1]}',
);

/// e.g. "সকাল ৬:৩০"
String banglaClock(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final period = local.hour < 4 || local.hour >= 19
      ? 'রাত'
      : local.hour < 12
      ? 'সকাল'
      : local.hour < 16
      ? 'দুপুর'
      : 'বিকেল';
  return banglaDigits(
    '$period $hour:${local.minute.toString().padLeft(2, '0')}',
  );
}
