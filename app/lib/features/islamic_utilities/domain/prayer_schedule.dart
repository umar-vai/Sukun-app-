class PrayerTimeEntry {
  const PrayerTimeEntry({
    required this.id,
    required this.label,
    required this.time,
    this.isPrayer = true,
  });

  final String id;
  final String label;
  final DateTime time;
  final bool isPrayer;
}

class PrayerDaySchedule {
  const PrayerDaySchedule({
    required this.date,
    required this.entries,
    required this.currentPrayer,
    required this.nextPrayer,
    required this.qiblaBearing,
  });

  final DateTime date;
  final List<PrayerTimeEntry> entries;
  final PrayerTimeEntry currentPrayer;
  final PrayerTimeEntry nextPrayer;
  final double qiblaBearing;
}
