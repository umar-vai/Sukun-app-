import 'package:flutter/widgets.dart';
import 'package:sukun_life/l10n/app_localizations.dart';

/// Only approved, user-facing messages can pass this boundary.
/// Never interpolate exception.toString(), SQL, HTTP details or provider errors.
final class FriendlyFailures {
  const FriendlyFailures._();

  static AppLocalizations? _copy(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations);

  static String generic(BuildContext context) =>
      _copy(context)?.genericFailure ??
      'তথ্যটি এখন পাওয়া যাচ্ছে না। আবার চেষ্টা করুন।';

  static String signIn(BuildContext context) =>
      _copy(context)?.signInFailed ??
      'প্রবেশ করা যায়নি। দেওয়া তথ্য ঠিক আছে কি না দেখে আবার চেষ্টা করুন।';
}
