import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/widgets/brand_logo.dart';
import 'package:sukun_life/core/widgets/sukun_launch_screen.dart';

void main() {
  testWidgets('launch screen uses the official brand asset', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SukunLaunchScreen()));

    expect(find.byType(SukunLifeLogo), findsOneWidget);
    expect(find.text('Faith. Care. Peace of mind.'), findsOneWidget);

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as AssetImage;
    expect(provider.assetName, BrandAssets.officialLogo);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
