/// Public-only OAuth failure handling. Never display arbitrary error descriptions,
/// URL query strings, identity data or tokens in browser-visible diagnostics.
///
/// Supabase may return an error in the query or fragment after Google redirects
/// back to the approved app URL. Successful PKCE/token callbacks are ignored.
String? googleOAuthWebFailureMessage(Uri callback) {
  final values = <String, String>{...callback.queryParameters};
  final fragment = callback.fragment;
  if (fragment.startsWith('error=') || fragment.startsWith('error_code=')) {
    try {
      values.addAll(Uri.splitQueryString(fragment));
    } on FormatException {
      return 'Google লগইন শেষ করা যায়নি। আবার চেষ্টা করুন। (S-OAUTH-00)';
    }
  }

  final error = values['error'];
  final code = values['error_code'];
  if (error == null && code == null) return null;

  if (error == 'access_denied' || code == 'access_denied') {
    return 'Google লগইন অনুমোদিত হয়নি বা বাতিল হয়েছে। '
        'Google অ্যাকাউন্টের অনুমতি ও পরীক্ষামূলক ব্যবহারকারীর তালিকা যাচাই করুন। '
        '(S-OAUTH-01)';
  }
  if (code == 'provider_disabled' || code == 'signup_disabled') {
    return 'Google লগইন এখনো সার্ভারে চালু নেই। '
        'অ্যাডমিনকে Google provider সেটআপ যাচাই করতে বলুন। (S-OAUTH-02)';
  }
  return 'Google লগইন সম্পন্ন হয়নি। Google OAuth অ্যাপ, অনুমোদিত '
      'Callback URL এবং Supabase Redirect URL যাচাই করতে হবে। (S-OAUTH-03)';
}
