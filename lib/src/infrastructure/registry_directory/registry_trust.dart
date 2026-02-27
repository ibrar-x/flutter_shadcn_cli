class RegistryTrust {
  final String mode;
  final String? sha256;

  const RegistryTrust({
    this.mode = 'none',
    this.sha256,
  });

  factory RegistryTrust.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const RegistryTrust();
    }
    return RegistryTrust(
      mode: json['mode']?.toString() ?? 'none',
      sha256: json['sha256']?.toString(),
    );
  }

  bool get isSha256 => mode.trim().toLowerCase() == 'sha256';
}
