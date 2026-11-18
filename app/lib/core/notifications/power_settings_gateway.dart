import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Android background-delivery controls that decide whether a locally
/// scheduled prayer or care alarm survives the phone's power management.
///
/// Every call is best effort and never throws. On Web, iOS and unsupported
/// devices the gateway reports "nothing to configure".
abstract interface class PowerSettingsGateway {
  /// True when the OS will not restrict this app's background alarms, or when
  /// the platform has no such restriction.
  Future<bool> isUnrestricted();

  /// Opens the system's one-tap battery optimisation dialog.
  Future<bool> requestUnrestricted();

  /// Opens the vendor autostart / protected-apps screen when one is known,
  /// otherwise the app's own system settings page.
  Future<bool> openAutostartSettings();

  /// Lower-case device maker, e.g. `huawei`, `honor`, `xiaomi`. Empty if unknown.
  Future<String> manufacturer();
}

final class MethodChannelPowerSettingsGateway implements PowerSettingsGateway {
  const MethodChannelPowerSettingsGateway();

  static const _channel = MethodChannel('sukunlife/power_settings');

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> isUnrestricted() async {
    if (!_supported) return true;
    try {
      return await _channel.invokeMethod<bool>(
            'isIgnoringBatteryOptimizations',
          ) ??
          true;
    } on Object {
      return true;
    }
  }

  @override
  Future<bool> requestUnrestricted() async {
    if (!_supported) return true;
    try {
      return await _channel.invokeMethod<bool>(
            'requestIgnoreBatteryOptimizations',
          ) ??
          false;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> openAutostartSettings() async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>('openAutostartSettings') ??
          false;
    } on Object {
      return false;
    }
  }

  @override
  Future<String> manufacturer() async {
    if (!_supported) return '';
    try {
      return await _channel.invokeMethod<String>('manufacturer') ?? '';
    } on Object {
      return '';
    }
  }
}

final powerSettingsGatewayProvider = Provider<PowerSettingsGateway>(
  (ref) => const MethodChannelPowerSettingsGateway(),
);

/// Makers whose power managers are known to cancel or delay alarms of apps
/// that are not on their protected / autostart list.
bool needsVendorAutostartStep(String manufacturer) => const {
  'huawei',
  'honor',
  'xiaomi',
  'redmi',
  'poco',
  'oppo',
  'realme',
  'oneplus',
  'vivo',
  'iqoo',
  'samsung',
  'tecno',
  'infinix',
  'itel',
}.contains(manufacturer.toLowerCase());
