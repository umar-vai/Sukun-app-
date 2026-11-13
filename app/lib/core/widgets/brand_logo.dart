import 'package:flutter/material.dart';

abstract final class BrandAssets {
  static const officialLogo = 'assets/brand/sukunlife_logo.png';
}

class SukunLifeLogo extends StatelessWidget {
  const SukunLifeLogo({super.key, this.height = 56});

  final double height;

  @override
  Widget build(BuildContext context) {
    // The source artwork is very large (3581x4219). Decode it at display size
    // so the launch screen and headers appear instantly and use little memory.
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final pixelHeight = (height * ratio).round();
    return Image.asset(
      BrandAssets.officialLogo,
      height: height,
      cacheHeight: pixelHeight,
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
