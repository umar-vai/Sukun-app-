import 'package:flutter/material.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/care_plans/domain/prescription_sections.dart';

Map<String, Object?> copyPrescriptionSchedule(PlanAction action) => {
  'frequency': action.frequency.toJson(),
  'start_date': prescriptionDate(action.startDate),
  'end_date': action.endDate == null ? null : prescriptionDate(action.endDate!),
  'time_window': action.timeWindow,
  'exact_time': action.exactTime == null
      ? null
      : prescriptionTime(action.exactTime!),
  'reminder_enabled': action.reminderEnabled,
};

class BatchPrescriptionSchedule extends StatefulWidget {
  const BatchPrescriptionSchedule({
    super.key,
    required this.plan,
    required this.selectedCount,
  });
  final CarePlan plan;
  final int selectedCount;

  @override
  State<BatchPrescriptionSchedule> createState() =>
      _BatchPrescriptionScheduleState();
}

class _BatchPrescriptionScheduleState extends State<BatchPrescriptionSchedule> {
  final _interval = TextEditingController(text: '1');
  final _weekdays = <int>{};
  String _recurrence = '';
  String _window = '';
  TimeOfDay? _time;
  DateTimeRange? _dates;
  bool? _remind;

  @override
  void dispose() {
    _interval.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final interval = int.tryParse(_interval.text);
    final hasChanges =
        _recurrence.isNotEmpty ||
        _window.isNotEmpty ||
        _time != null ||
        _dates != null ||
        _remind != null;
    final valid =
        hasChanges &&
        (_recurrence != 'daily' ||
            (interval != null && interval >= 1 && interval <= 999)) &&
        (_recurrence != 'weekly' || _weekdays.isNotEmpty);
    return AlertDialog(
      title: Text('${widget.selectedCount}টি করণীয়ের সময়সূচি'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'যে সেটিংগুলো বেছে নেবেন, শুধু সেগুলো বদলাবে। বদলানো করণীয় আবার যাচাই করতে হবে।',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField(
                initialValue: _window,
                decoration: const InputDecoration(labelText: 'দিনের সময়'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('অপরিবর্তিত')),
                  DropdownMenuItem(value: 'morning', child: Text('সকাল')),
                  DropdownMenuItem(value: 'afternoon', child: Text('দুপুর')),
                  DropdownMenuItem(value: 'evening', child: Text('সন্ধ্যা')),
                  DropdownMenuItem(
                    value: 'night',
                    child: Text('রাত / ঘুমের আগে'),
                  ),
                  DropdownMenuItem(value: 'anytime', child: Text('যেকোনো সময়')),
                ],
                onChanged: (value) => setState(() => _window = value!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField(
                initialValue: _recurrence,
                decoration: const InputDecoration(labelText: 'পুনরাবৃত্তি'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('অপরিবর্তিত')),
                  DropdownMenuItem(
                    value: 'daily',
                    child: Text('প্রতিদিন / প্রতি কয়েক দিন'),
                  ),
                  DropdownMenuItem(
                    value: 'weekly',
                    child: Text('সপ্তাহের নির্বাচিত দিন'),
                  ),
                ],
                onChanged: (value) => setState(() => _recurrence = value!),
              ),
              if (_recurrence == 'daily')
                TextField(
                  controller: _interval,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'কত দিন পরপর'),
                  onChanged: (_) => setState(() {}),
                ),
              if (_recurrence == 'weekly')
                Wrap(
                  spacing: 6,
                  children: [
                    for (final (index, label) in const [
                      'সোম',
                      'মঙ্গল',
                      'বুধ',
                      'বৃহস্পতি',
                      'শুক্র',
                      'শনি',
                      'রবি',
                    ].indexed)
                      FilterChip(
                        label: Text(label),
                        selected: _weekdays.contains(index + 1),
                        onSelected: (value) => setState(() {
                          if (value) {
                            _weekdays.add(index + 1);
                          } else {
                            _weekdays.remove(index + 1);
                          }
                        }),
                      ),
                  ],
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.access_time),
                label: Text(_time?.format(context) ?? 'নির্দিষ্ট সময় বেছে নিন'),
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _time ?? TimeOfDay.now(),
                  );
                  if (mounted && picked != null) setState(() => _time = picked);
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.date_range_outlined),
                label: Text(
                  _dates == null
                      ? 'শুরু ও শেষের তারিখ'
                      : '${prescriptionDate(_dates!.start)} – ${prescriptionDate(_dates!.end)}',
                ),
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: widget.plan.startDate,
                    lastDate:
                        widget.plan.endDate ??
                        DateTime(widget.plan.startDate.year + 10),
                    initialDateRange: _dates,
                  );
                  if (mounted && picked != null) {
                    setState(() => _dates = picked);
                  }
                },
              ),
              DropdownButtonFormField(
                initialValue: 'keep',
                decoration: const InputDecoration(labelText: 'রিমাইন্ডার'),
                items: const [
                  DropdownMenuItem(value: 'keep', child: Text('অপরিবর্তিত')),
                  DropdownMenuItem(value: 'on', child: Text('চালু')),
                  DropdownMenuItem(value: 'off', child: Text('বন্ধ')),
                ],
                onChanged: (value) => setState(
                  () => _remind = switch (value) {
                    'on' => true,
                    'off' => false,
                    _ => null,
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ফিরে যান'),
        ),
        FilledButton(
          onPressed: valid
              ? () {
                  Navigator.pop(context, <String, Object?>{
                    if (_window.isNotEmpty) 'time_window': _window,
                    if (_recurrence == 'daily')
                      'frequency': ActionFrequency.daily(interval: interval!)
                          .toJson(),
                    if (_recurrence == 'weekly')
                      'frequency': ActionFrequency.weekly(_weekdays).toJson(),
                    if (_dates != null)
                      'start_date': prescriptionDate(_dates!.start),
                    if (_dates != null)
                      'end_date': prescriptionDate(_dates!.end),
                    if (_time != null)
                      'exact_time': prescriptionTime(
                        DateTime(2000, 1, 1, _time!.hour, _time!.minute),
                      ),
                    if (_remind != null) 'reminder_enabled': _remind,
                  });
                }
              : null,
          child: const Text('খসড়ায় প্রয়োগ করুন'),
        ),
      ],
    );
  }
}
