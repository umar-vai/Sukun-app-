import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/features/islamic_utilities/data/islamic_utilities_providers.dart';
import 'package:sukun_life/features/islamic_utilities/data/utility_location_gateway.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_settings.dart';
import 'package:sukun_life/features/islamic_utilities/domain/utility_location.dart';

class PrayerSettingsScreen extends ConsumerStatefulWidget {
  const PrayerSettingsScreen({super.key});

  @override
  ConsumerState<PrayerSettingsScreen> createState() =>
      _PrayerSettingsScreenState();
}

class _PrayerSettingsScreenState extends ConsumerState<PrayerSettingsScreen> {
  PrayerCalculationMethodOption? _method;
  AsrConvention? _asrConvention;
  UtilityLocation? _location;
  bool _loading = true;
  bool _locating = false;
  bool _saving = false;
  LocationAccessException? _locationFailure;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await ref.read(utilityPreferencesStoreProvider).load();
    if (!mounted) return;
    setState(() {
      _method = settings.calculationMethod;
      _asrConvention = settings.asrConvention;
      _location = settings.location;
      _loading = false;
    });
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locationFailure = null;
    });
    try {
      final location = await ref
          .read(utilityLocationGatewayProvider)
          .requestCurrentLocation();
      if (!mounted) return;
      setState(() => _location = location);
    } on LocationAccessException catch (error) {
      if (!mounted) return;
      setState(() => _locationFailure = error);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    if (_saving ||
        _method == null ||
        _asrConvention == null ||
        _location == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(utilityPreferencesStoreProvider)
          .save(
            PrayerUtilitySettings(
              location: _location,
              calculationMethod: _method,
              asrConvention: _asrConvention,
            ),
          );
      if (mounted) context.pop(true);
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prayer settings could not be saved. Please retry.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prayer settings')),
      body: _loading
          ? const AppLoadingState(label: 'Loading settings')
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                Text('Location', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_location != null) ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                color: SukunColors.deepTide,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _location!.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        const Text(
                          'Location is stored on this device for calculation and is not added to patient care records.',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: _locating ? null : _useCurrentLocation,
                          icon: _locating
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.my_location),
                          label: Text(
                            _locating
                                ? 'Finding location'
                                : 'Use current location',
                          ),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<UtilityLocation>(
                          initialValue: _manualSelection,
                          decoration: const InputDecoration(
                            labelText: 'Or select a Bangladesh city',
                          ),
                          items: [
                            for (final city in manualBangladeshCities)
                              DropdownMenuItem(
                                value: city,
                                child: Text(city.name),
                              ),
                          ],
                          onChanged: (city) {
                            if (city != null) setState(() => _location = city);
                          },
                        ),
                        if (_locationFailure != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _locationFailure!.userMessage,
                            style: const TextStyle(color: SukunColors.error),
                          ),
                          if (_locationFailure!.failure ==
                              LocationAccessFailure.deniedForever)
                            TextButton(
                              onPressed: () => ref
                                  .read(utilityLocationGatewayProvider)
                                  .openAppSettings(),
                              child: const Text('Open app settings'),
                            ),
                          if (_locationFailure!.failure ==
                              LocationAccessFailure.serviceDisabled)
                            TextButton(
                              onPressed: () => ref
                                  .read(utilityLocationGatewayProvider)
                                  .openLocationSettings(),
                              child: const Text('Open location settings'),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Calculation method',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<PrayerCalculationMethodOption>(
                  initialValue: _method,
                  decoration: const InputDecoration(
                    labelText: 'Choose a calculation method',
                  ),
                  items: [
                    for (final method in PrayerCalculationMethodOption.values)
                      DropdownMenuItem(
                        value: method,
                        child: Text(
                          method.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _method = value),
                ),
                if (_method != null) ...[
                  const SizedBox(height: 7),
                  Text(_method!.description),
                ],
                const SizedBox(height: 20),
                DropdownButtonFormField<AsrConvention>(
                  initialValue: _asrConvention,
                  decoration: const InputDecoration(
                    labelText: 'Choose an Asr convention',
                  ),
                  items: [
                    for (final convention in AsrConvention.values)
                      DropdownMenuItem(
                        value: convention,
                        child: Text(
                          convention.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _asrConvention = value),
                ),
                if (_asrConvention != null) ...[
                  const SizedBox(height: 7),
                  Text(_asrConvention!.description),
                ],
                const SizedBox(height: 14),
                const Text(
                  'These settings affect calculated utility times only. They do not change a patient care plan or any prescribed reminder.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed:
                      _location != null &&
                          _method != null &&
                          _asrConvention != null &&
                          !_saving
                      ? _save
                      : null,
                  icon: const Icon(Icons.check),
                  label: Text(_saving ? 'Saving' : 'Save prayer settings'),
                ),
              ],
            ),
    );
  }

  UtilityLocation? get _manualSelection {
    if (_location?.source != UtilityLocationSource.manual) return null;
    for (final city in manualBangladeshCities) {
      if (city.id == _location!.id) return city;
    }
    return null;
  }
}
