import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pdfrx/pdfrx.dart';

/// Opt-in font substitution for externally hosted Bengali-language PDFs.
///
/// PDFium/WASM does not have access to the phone's installed fonts. When the
/// PDF requests a non-embedded face, register a Bengali-capable fallback under
/// that requested face. This does not modify or copy the externally hosted PDF.
///
/// Source: Noto Sans Bengali Regular (SIL Open Font License 1.1).
/// Archived upstream: https://github.com/notofonts/noto-fonts
class BengaliPdfFontResolver implements PdfFontResolver {
  const BengaliPdfFontResolver();

  static final Uri fontUri = Uri.parse(
    'https://raw.githubusercontent.com/notofonts/noto-fonts/'
    'main/hinted/ttf/NotoSansBengali/NotoSansBengali-Regular.ttf',
  );

  static Future<Uint8List>? _pendingFont;

  @override
  PdfFontResolution? resolve(
    PdfFontQuery query,
    PdfFontResolveContext context,
  ) {
    final face = query.face.toLowerCase();
    if (query.charset == PdfFontCharset.symbol ||
        face.contains('wingdings') ||
        face.contains('symbol') ||
        face.isEmpty) {
      return null;
    }

    return PdfFontResolution(
      targetFace: query.face,
      resolvedFace: 'Noto Sans Bengali',
      source: fontUri,
      loadData: ({onProgress}) async {
        final data = await _loadFontBytes();
        onProgress?.call(loaded: data.length, total: data.length);
        return data;
      },
    );
  }

  static Future<Uint8List> _loadFontBytes() async {
    _pendingFont ??= _downloadFont();
    try {
      return await _pendingFont!;
    } catch (_) {
      // A temporary network problem should not permanently poison retries.
      _pendingFont = null;
      rethrow;
    }
  }

  static Future<Uint8List> _downloadFont() async {
    final response = await http
        .get(fontUri)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError('Bengali PDF fallback font is unavailable');
    }
    final bytes = response.bodyBytes;
    // A small fixed TrueType file is expected; reject HTML error responses.
    if (bytes.length < 50000 ||
        bytes.length > 1000000 ||
        bytes[0] != 0 ||
        bytes[1] != 1 ||
        bytes[2] != 0 ||
        bytes[3] != 0) {
      throw const FormatException('Invalid PDF fallback font');
    }
    return bytes;
  }
}
