class UtilityLocation {
  const UtilityLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.timezone,
    required this.source,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String timezone;
  final UtilityLocationSource source;

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'timezone': timezone,
    'source': source.name,
  };

  factory UtilityLocation.fromJson(Map<String, Object?> json) {
    return UtilityLocation(
      id: json['id']! as String,
      name: json['name']! as String,
      latitude: (json['latitude']! as num).toDouble(),
      longitude: (json['longitude']! as num).toDouble(),
      timezone: json['timezone']! as String,
      source: UtilityLocationSource.values.byName(json['source']! as String),
    );
  }
}

enum UtilityLocationSource { device, manual }

const manualBangladeshCities = <UtilityLocation>[
  UtilityLocation(
    id: 'dhaka',
    name: 'Dhaka',
    latitude: 23.8103,
    longitude: 90.4125,
    timezone: 'Asia/Dhaka',
    source: UtilityLocationSource.manual,
  ),
  UtilityLocation(
    id: 'chattogram',
    name: 'Chattogram',
    latitude: 22.3569,
    longitude: 91.7832,
    timezone: 'Asia/Dhaka',
    source: UtilityLocationSource.manual,
  ),
  UtilityLocation(
    id: 'sylhet',
    name: 'Sylhet',
    latitude: 24.8949,
    longitude: 91.8687,
    timezone: 'Asia/Dhaka',
    source: UtilityLocationSource.manual,
  ),
  UtilityLocation(
    id: 'rajshahi',
    name: 'Rajshahi',
    latitude: 24.3745,
    longitude: 88.6042,
    timezone: 'Asia/Dhaka',
    source: UtilityLocationSource.manual,
  ),
  UtilityLocation(
    id: 'khulna',
    name: 'Khulna',
    latitude: 22.8456,
    longitude: 89.5403,
    timezone: 'Asia/Dhaka',
    source: UtilityLocationSource.manual,
  ),
  UtilityLocation(
    id: 'barishal',
    name: 'Barishal',
    latitude: 22.7010,
    longitude: 90.3535,
    timezone: 'Asia/Dhaka',
    source: UtilityLocationSource.manual,
  ),
  UtilityLocation(
    id: 'rangpur',
    name: 'Rangpur',
    latitude: 25.7439,
    longitude: 89.2752,
    timezone: 'Asia/Dhaka',
    source: UtilityLocationSource.manual,
  ),
  UtilityLocation(
    id: 'mymensingh',
    name: 'Mymensingh',
    latitude: 24.7471,
    longitude: 90.4203,
    timezone: 'Asia/Dhaka',
    source: UtilityLocationSource.manual,
  ),
];
