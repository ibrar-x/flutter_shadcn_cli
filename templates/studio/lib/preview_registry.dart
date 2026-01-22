import 'package:flutter/material.dart';

class ComponentPreview {
  final String id;
  final WidgetBuilder builder;
  final bool isFallback;

  const ComponentPreview({
    required this.id,
    required this.builder,
    this.isFallback = false,
  });

  factory ComponentPreview.fallback(String id) {
    return ComponentPreview(
      id: id,
      isFallback: true,
      builder: (context) {
        return const Center(
          child: Text('No preview available'),
        );
      },
    );
  }
}

final List<ComponentPreview> previewRegistry = [];

Widget wrapPreviewTheme(Map<String, String> values, Widget child) {
  final colors = <String, Color>{};
  for (final entry in values.entries) {
    final color = _colorFromHex(entry.value);
    if (color != null) {
      colors[entry.key] = color;
    }
  }
  if (colors.isEmpty) {
    return child;
  }
  final background = colors['background'];
  final brightness = background != null && background.computeLuminance() < 0.4
      ? Brightness.dark
      : Brightness.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: colors['primary'] ?? colors['card'] ?? Colors.blue,
    onPrimary: colors['primaryForeground'] ?? Colors.white,
    secondary: colors['secondary'] ?? colors['accent'] ?? Colors.blueGrey,
    onSecondary: colors['secondaryForeground'] ?? Colors.white,
    surface: colors['card'] ?? Colors.grey.shade900,
    onSurface: colors['cardForeground'] ?? Colors.white,
    background: background ?? Colors.black,
    onBackground: colors['foreground'] ?? Colors.white,
    error: colors['destructive'] ?? Colors.red,
    onError: colors['destructiveForeground'] ?? Colors.white,
    surfaceVariant: colors['popover'] ?? colors['card'] ?? Colors.grey,
    outline: colors['border'] ?? Colors.white.withOpacity(0.2),
    outlineVariant: colors['sidebarBorder'] ?? Colors.white24,
    shadow: Colors.black.withOpacity(0.4),
    tertiary: colors['accent'] ?? Colors.orange,
    onTertiary: colors['accentForeground'] ??
        (brightness == Brightness.dark ? Colors.white : Colors.black),
  );
  final theme = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
  );
  return Theme(
    data: theme,
    child: child,
  );
}

Color? _colorFromHex(String value) {
  final hex = value.replaceAll('#', '');
  if (hex.length == 6) {
    return Color(int.parse('FF$hex', radix: 16));
  }
  if (hex.length == 8) {
    return Color(int.parse(hex, radix: 16));
  }
  return null;
}
