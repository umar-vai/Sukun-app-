import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
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
                const SukunPageIntro(
                  eyebrow: 'Personal preference',
                  title: 'Set your prayer timetable',
                  subtitle: 'Choose the location and scholarly calculation settings you follow. Nothing is selected automatically.',
                ),
                const SizedBox(height: 26),
                const SukunSectionHeader(
                  title: 'Your location',
                  subtitle: 'Used only for on-device calculation',
                ),
                const SizedBox(height: 10),
                SukunSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          SukunIconBadge(
                            icon:
                                _location?.source ==
                                    UtilityLocationSource.device
                                ? Icons.my_location_rounded
                                : Icons.location_city_rounded,
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _location?.name ?? 'Location not selected',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Stored privately on this device',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: SukunColors.muted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton.tonalIcon(
                        onPressed: _locating ? null : _useCurrentLocation,
                        icon: _locating
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.near_me_rounded),
                        label: Text(
                          _locating
                              ? 'Finding your location'
                              : 'Use current location',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SukunChoiceField<UtilityLocation>(
                        label: 'Or select a Bangladesh city',
                        placeholder: 'Select a Bangladesh city',
                        sheetTitle: 'Choose a city',
                        value: _manualSelection,
                        options: [
                          for (final city in manualBangladeshCities)
                            SukunChoiceOption(
                              value: city,
                              title: city.name,
                              description: 'Bangladesh · Asia/Dhaka',
                              icon: Icons.location_city_rounded,
                            ),
                        ],
                        onChanged: (city) => setState(() {
                          _location = city;
                          _locationFailure = null;
                        }),
                      ),
                      if (_locationFailure != null) ...[
                        const SizedBox(height: 12),
                        SukunSurface(
                          tone: SukunSurfaceTone.warning,
                          radius: 16,
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_locationFailure!.userMessage),
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
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                const SukunSectionHeader(
                  title: 'Calculation preferences',
                  subtitle: 'Choose the convention you personally follow',
                ),
                const SizedBox(height: 10),
                SukunChoiceField<PrayerCalculationMethodOption>(
                  label: 'Calculation method',
                  placeholder: 'Choose a method',
                  sheetTitle: 'Calculation method',
                  value: _method,
                  options: [
                    for (final method in PrayerCalculationMethodOption.values)
                      SukunChoiceOption(
                        value: method,
                        title: method.label,
                        description: method.description,
                        icon: Icons.calculate_outlined,
                      ),
                  ],
                  onChanged: (method) => setState(() => _method = method),
                ),
                const SizedBox(height: 12),
                SukunChoiceField<AsrConvention>(
                  label: 'Asr convention',
                  placeholder: 'Choose an Asr convention',
                  sheetTitle: 'Asr convention',
                  value: _asrConvention,
                  options: [
                    for (final convention in AsrConvention.values)
                      SukunChoiceOption(
                        value: convention,
                        title: convention.label,
                        description: convention.description,
                        icon: Icons.wb_twilight_rounded,
                      ),
                  ],
                  onChanged: (convention) =>
                      setState(() => _asrConvention = convention),
                ),
                const SizedBox(height: 16),
                const SukunSurface(
                  tone: SukunSurfaceTone.soft,
                  radius: 18,
                  showBorder: false,
                  padding: EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: SukunColors.deepTide,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'These preferences affect this utility only. They never change a care plan or prescribed reminder.',
                        ),
                      ),
                    ],
                  ),
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
