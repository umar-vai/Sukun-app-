import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:sukun_life/core/media/bengali_pdf_font_resolver.dart';

void main() {
  const resolver = BengaliPdfFontResolver();
  const context = PdfFontResolveContext();

  test('can substitute missing PDFium text face with Bengali-capable TTF', () {
    const query = PdfFontQuery(
      face: 'Times New Roman',
      weight: 400,
      isItalic: false,
      charset: PdfFontCharset.ansi,
      pitchFamily: 0,
    );
    final result = resolver.resolve(query, context);
    expect(result, isNotNull);
    expect(result!.targetFace, 'Times New Roman');
    expect(result.resolvedFace, 'Noto Sans Bengali');
    expect(result.source?.scheme, 'https');
    expect(result.source?.host, 'raw.githubusercontent.com');
    expect(result.source?.path.endsWith('.ttf'), isTrue);
    expect(result.loadData, isNotNull);
  });

  test('preserves Wingdings and PDF symbol fonts without substitution', () {
    const symbol = PdfFontQuery(
      face: 'Wingdings',
      weight: 400,
      isItalic: false,
      charset: PdfFontCharset.symbol,
      pitchFamily: 0,
    );
    const namedSymbol = PdfFontQuery(
      face: 'Symbol',
      weight: 400,
      isItalic: false,
      charset: PdfFontCharset.ansi,
      pitchFamily: 0,
    );
    expect(resolver.resolve(symbol, context), isNull);
    expect(resolver.resolve(namedSymbol, context), isNull);
  });
}
