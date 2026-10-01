class ContentResourceOption {
  const ContentResourceOption({
    required this.id,
    required this.title,
    required this.type,
    required this.visibility,
    this.titleBn,
  });

  factory ContentResourceOption.fromJson(Map<String, dynamic> json) {
    return ContentResourceOption(
      id: json['id'] as String,
      title: json['title'] as String,
      titleBn: json['title_bn'] as String?,
      type: json['type'] as String,
      visibility: json['visibility'] as String,
    );
  }

  final String id;
  final String title;
  final String? titleBn;
  final String type;
  final String visibility;
}
