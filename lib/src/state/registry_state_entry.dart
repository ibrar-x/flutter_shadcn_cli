class RegistryStateEntry {
  final String? installPath;
  final String? sharedPath;
  final String? themeId;

  const RegistryStateEntry({
    this.installPath,
    this.sharedPath,
    this.themeId,
  });

  factory RegistryStateEntry.fromJson(Map<String, dynamic> json) {
    return RegistryStateEntry(
      installPath: json['installPath'] as String?,
      sharedPath: json['sharedPath'] as String?,
      themeId: json['themeId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'installPath': installPath,
      'sharedPath': sharedPath,
      'themeId': themeId,
    };
  }
}
