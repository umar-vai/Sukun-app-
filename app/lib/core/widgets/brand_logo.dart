import 'package:flutter/material.dart';

abstract final class BrandAssets {
  static const officialLogo = 'assets/brand/sukunlife_logo.png';
}

class SukunLifeLogo extends StatelessWidget {
  const SukunLifeLogo({super.key, this.height = 56});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      BrandAssets.officialLogo,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Text(
          'Sukun Life',
          style: Theme.of(context).textTheme.headlineMedium,
        );
      },
    );
  }
}
