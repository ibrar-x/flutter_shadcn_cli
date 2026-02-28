import 'package:flutter_shadcn_cli/src/registry/font_asset.dart';

class FontEntry {
  final String family;
  final List<FontAsset> fonts;

  FontEntry.fromJson(Map<String, dynamic> json)
      : family = json['family'] as String,
        fonts = (json['fonts'] as List<dynamic>? ?? const [])
            .map((e) => FontAsset.fromJson(e as Map<String, dynamic>))
            .toList();
}
