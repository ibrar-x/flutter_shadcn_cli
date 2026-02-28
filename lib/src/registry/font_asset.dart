class FontAsset {
  final String asset;
  final int? weight;
  final String? style;

  FontAsset.fromJson(Map<String, dynamic> json)
      : asset = json['asset'] as String,
        weight = json['weight'] as int?,
        style = json['style'] as String?;
}
