import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/brand_logo.dart';

class SukunLaunchScreen extends StatelessWidget {
  const SukunLaunchScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SukunLifeLogo(height: 220),
              const SizedBox(height: 28),
              Text(
                'Faith. Care. Peace of mind.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 120,
                child: LinearProgressIndicator(
                  borderRadius: BorderRadius.all(Radius.circular(99)),
                  color: SukunColors.sukunBlue,
                  backgroundColor: SukunColors.deepTide,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
