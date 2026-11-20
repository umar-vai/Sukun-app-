import 'package:flutter/material.dart';

abstract final class BrandAssets {
  static const officialLogo = 'assets/brand/sukunlife_logo.png';

  /// The same official artwork, only scaled down (543x640) for on-screen
  /// use. The 872 KB source made the web launch screen wait on a large
  /// download; PDFs and launcher icons still use [officialLogo].
  static const displayLogo = 'assets/brand/sukunlife_logo_display.png';
}

class SukunLifeLogo extends StatelessWidget {
  const SukunLifeLogo({super.key, this.height = 56});

  final double height;

  @override
  Widget build(BuildContext context) {
    // Decode at display size so the launch screen and headers appear
    // instantly and use little memory.
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final pixelHeight = (height * ratio).round();
    return Image.asset(
      BrandAssets.displayLogo,
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
