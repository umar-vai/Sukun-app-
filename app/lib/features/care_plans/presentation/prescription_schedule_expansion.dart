import 'package:flutter/material.dart';

typedef PrescriptionScheduleExpansion = ({
  List<int>? stageDays,
  List<String>? times,
});

class PrescriptionScheduleExpansionDialog extends StatefulWidget {
  const PrescriptionScheduleExpansionDialog({super.key, required this.title});
  final String title;

  @override
  State<PrescriptionScheduleExpansionDialog> createState() => _ExpansionState();
}

class _ExpansionState extends State<PrescriptionScheduleExpansionDialog> {
  String _preset = 'stages';
  String _input = '';

  @override
  Widget build(BuildContext context) {
    final values = _input.split(',').map((value) => value.trim()).toList();
    final days = values.map(int.tryParse).toList();
    final stages = _preset == 'stages';
    final valid =
        values.length >= 2 &&
        values.length <= 12 &&
        (stages
            ? days.every((day) => day != null && day >= 1 && day <= 365)
            : values.toSet().length == values.length &&
                  values.every(
                    (time) =>
                        RegExp(r'^([01][0-9]|2[0-3]):[0-5][0-9]$')
                            .hasMatch(time),
                  )) &&
        (_preset != 'morning-evening' || values.length == 2);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField(
                initialValue: _preset,
                decoration: const InputDecoration(labelText: 'সময়সূচির ধরন'),
                items: const [
                  DropdownMenuItem(
                    value: 'stages',
                    child: Text('ধারাবাহিক ধাপ'),
                  ),
                  DropdownMenuItem(
                    value: 'morning-evening',
                    child: Text('সকাল ও সন্ধ্যা'),
                  ),
                  DropdownMenuItem(
                    value: 'times',
                    child: Text('দিনে একাধিক সময়'),
                  ),
                ],
                onChanged: (value) => setState(() => _preset = value!),
              ),
              const SizedBox(height: 14),
              TextField(
                onChanged: (value) => setState(() => _input = value),
                decoration: InputDecoration(
                  labelText: stages
                      ? 'প্রতি ধাপের দিন'
                      : 'নির্দিষ্ট সময় (২৪ ঘণ্টা)',
                  hintText: stages ? '3, 7, 4' : '08:00, 19:00',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                stages
                    ? 'প্রথম ধাপ বর্তমান শুরুর তারিখে শুরু হবে। পরের ধাপ আগের ধাপ শেষ হওয়ার পরদিন শুরু হবে।'
                    : 'প্রতি নির্দিষ্ট সময়ের জন্য আলাদা করণীয় তৈরি হবে।',
              ),
              const SizedBox(height: 8),
              const Text(
                'প্রতিটি করণীয় যাচাই করুন এবং প্রয়োজন হলে রিমাইন্ডার চালু করুন।',
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
          onPressed: !valid
              ? null
              : () {
                  Navigator.pop<PrescriptionScheduleExpansion>(context, (
                    stageDays: stages ? days.nonNulls.toList() : null,
                    times: stages ? null : values,
                  ));
                },
          child: const Text('খসড়ায় প্রয়োগ করুন'),
        ),
      ],
    );
  }
}
